#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <linux/ethtool.h>
#include <linux/if_packet.h>
#include <linux/sockios.h>
#include <net/if.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <unistd.h>

#define APP_VERSION "0.2.1"
#define LLDP_ETHERTYPE 0x88cc
#define DEFAULT_IFACE "eth0"
#define DEFAULT_TTL 120
#define DEFAULT_INTERVAL 30

static volatile sig_atomic_t stopping;

static void on_signal(int sig) { (void)sig; stopping = 1; }

static uint8_t *put_tlv(uint8_t *p, uint8_t type, const void *data, uint16_t len)
{
    uint16_t hdr = htons(((uint16_t)type << 9) | (len & 0x01ff));
    memcpy(p, &hdr, 2); p += 2;
    if (len) { memcpy(p, data, len); p += len; }
    return p;
}

static void trim(char *s)
{
    size_t n;
    while (*s == ' ' || *s == '\t') memmove(s, s + 1, strlen(s));
    n = strlen(s);
    while (n && (s[n-1] == '\n' || s[n-1] == '\r' || s[n-1] == ' ' || s[n-1] == '\t')) s[--n] = 0;
    if (n >= 2 && ((s[0] == '"' && s[n-1] == '"') || (s[0] == '\'' && s[n-1] == '\''))) {
        memmove(s, s + 1, n - 2); s[n - 2] = 0;
    }
}

static int osrel(const char *key, char *out, size_t outlen)
{
    FILE *f = fopen("/etc/os-release", "r");
    char line[384]; size_t k = strlen(key);
    if (!f) return -1;
    while (fgets(line, sizeof(line), f)) {
        if (!strncmp(line, key, k) && line[k] == '=') {
            snprintf(out, outlen, "%s", line + k + 1); trim(out); fclose(f); return 0;
        }
    }
    fclose(f); return -1;
}

static void make_description(char *out, size_t n)
{
    char v[64] = "", p[96] = "", b[128] = "";
    struct utsname u;
    osrel("OPENIPC_VERSION", v, sizeof(v));
    osrel("BUILD_PLATFORM", p, sizeof(p));
    osrel("BUILD_ID", b, sizeof(b));
    if (v[0] || p[0] || b[0]) {
        snprintf(out, n, "OpenIPC%s%s%s%s%s%s",
                 v[0] ? " " : "", v,
                 p[0] ? " | " : "", p,
                 b[0] ? " | " : "", b);
    } else if (!uname(&u)) {
        snprintf(out, n, "OpenIPC | Linux %s %s", u.release, u.machine);
    } else snprintf(out, n, "OpenIPC camera");
}

static int get_ipv4(int io, const char *ifname, struct in_addr *addr)
{
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);
    if (ioctl(io, SIOCGIFADDR, &ifr) < 0) return -1;
    *addr = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr;
    return 0;
}

struct phy_info {
    int valid;
    uint8_t autoneg;        /* bit0 supported, bit1 enabled */
    uint16_t pmd;           /* 802.3 PMD autoneg capabilities */
    uint16_t mau;           /* operational MAU type */
};

static uint16_t pmd_from_ethtool(uint32_t a)
{
    uint16_t p = 0;
#ifdef ADVERTISED_1000baseT_Full
    if (a & ADVERTISED_1000baseT_Full) p |= (1u << 0);
#endif
#ifdef ADVERTISED_1000baseT_Half
    if (a & ADVERTISED_1000baseT_Half) p |= (1u << 1);
#endif
#ifdef ADVERTISED_100baseT_Full
    if (a & ADVERTISED_100baseT_Full) p |= (1u << 10);
#endif
#ifdef ADVERTISED_100baseT_Half
    if (a & ADVERTISED_100baseT_Half) p |= (1u << 11);
#endif
#ifdef ADVERTISED_Pause
    if (a & ADVERTISED_Pause) p |= (1u << 8);
#endif
#ifdef ADVERTISED_Asym_Pause
    if (a & ADVERTISED_Asym_Pause) p |= (1u << 9);
#endif
#ifdef ADVERTISED_10baseT_Full
    if (a & ADVERTISED_10baseT_Full) p |= (1u << 13);
#endif
#ifdef ADVERTISED_10baseT_Half
    if (a & ADVERTISED_10baseT_Half) p |= (1u << 14);
#endif
    return p;
}

static uint16_t mau_from_link(unsigned speed, unsigned duplex)
{
    if (speed == 10)   return duplex == DUPLEX_FULL ? 11 : 10;
    if (speed == 100)  return duplex == DUPLEX_FULL ? 16 : 15;
    if (speed == 1000) return duplex == DUPLEX_FULL ? 30 : 29;
    return 0;
}

static struct phy_info get_phy(int io, const char *ifname)
{
    struct phy_info pi = {0};
    struct ifreq ifr;
    struct ethtool_cmd ecmd;
    uint32_t adv;
    memset(&ifr, 0, sizeof(ifr)); memset(&ecmd, 0, sizeof(ecmd));
    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);
    ecmd.cmd = ETHTOOL_GSET;
    ifr.ifr_data = (void *)&ecmd;
    if (ioctl(io, SIOCETHTOOL, &ifr) < 0) return pi;

    pi.valid = 1;
#ifdef SUPPORTED_Autoneg
    if (ecmd.supported & SUPPORTED_Autoneg) pi.autoneg |= 1;
#endif
    if (ecmd.autoneg == AUTONEG_ENABLE) pi.autoneg |= 2;
    adv = ecmd.advertising ? ecmd.advertising : ecmd.supported;
    pi.pmd = pmd_from_ethtool(adv);
    pi.mau = mau_from_link(ethtool_cmd_speed(&ecmd), ecmd.duplex);
    return pi;
}

static int send_lldp(int raw, int io, int ifindex, const char *ifname,
                     const uint8_t mac[6], const char *name, const char *desc,
                     unsigned ttl)
{
    static const uint8_t dst[6] = {0x01,0x80,0xc2,0x00,0x00,0x0e};
    uint8_t frame[512], *p = frame;
    struct ethhdr *eth = (struct ethhdr *)p;
    struct sockaddr_ll sa;
    struct in_addr ip;
    struct phy_info phy;

    memcpy(eth->h_dest, dst, 6); memcpy(eth->h_source, mac, 6);
    eth->h_proto = htons(LLDP_ETHERTYPE); p += sizeof(*eth);

    { uint8_t v[7] = {4}; memcpy(v + 1, mac, 6); p = put_tlv(p, 1, v, 7); }
    { uint8_t v[1 + IFNAMSIZ]; size_t l = strnlen(ifname, IFNAMSIZ - 1); v[0] = 5; memcpy(v + 1, ifname, l); p = put_tlv(p, 2, v, l + 1); }
    { uint16_t v = htons((uint16_t)ttl); p = put_tlv(p, 3, &v, 2); }
    p = put_tlv(p, 4, ifname, strlen(ifname));
    p = put_tlv(p, 5, name, strlen(name));
    p = put_tlv(p, 6, desc, strlen(desc));
    { uint16_t s = htons(0x0080), e = htons(0x0080); uint8_t v[4]; memcpy(v,&s,2); memcpy(v+2,&e,2); p = put_tlv(p,7,v,4); }

    if (ttl && get_ipv4(io, ifname, &ip) == 0) {
        uint8_t v[12], *m = v; uint32_t idx = htonl((uint32_t)ifindex);
        *m++ = 5; *m++ = 1; memcpy(m,&ip,4); m += 4; *m++ = 2; memcpy(m,&idx,4); m += 4; *m++ = 0;
        p = put_tlv(p, 8, v, m - v);
    }

    /* IEEE 802.3 MAC/PHY Configuration/Status TLV (OUI 00:12:0f, subtype 1). */
    phy = get_phy(io, ifname);
    if (ttl && phy.valid) {
        uint8_t v[9] = {0x00,0x12,0x0f,0x01,0,0,0,0,0};
        uint16_t pmd = htons(phy.pmd), mau = htons(phy.mau);
        v[4] = phy.autoneg; memcpy(v+5,&pmd,2); memcpy(v+7,&mau,2);
        p = put_tlv(p, 127, v, sizeof(v));

        /* IEEE 802.3 Maximum Frame Size TLV (subtype 4). */
        {
            struct ifreq ifr; uint8_t mfs[6] = {0x00,0x12,0x0f,0x04,0,0};
            memset(&ifr,0,sizeof(ifr)); snprintf(ifr.ifr_name,sizeof(ifr.ifr_name),"%s",ifname);
            if (ioctl(io,SIOCGIFMTU,&ifr) == 0) {
                uint16_t mtu = htons((uint16_t)ifr.ifr_mtu); memcpy(mfs+4,&mtu,2);
                p = put_tlv(p,127,mfs,sizeof(mfs));
            }
        }
    }

    p = put_tlv(p,0,NULL,0);
    memset(&sa,0,sizeof(sa)); sa.sll_family=AF_PACKET; sa.sll_protocol=htons(LLDP_ETHERTYPE); sa.sll_ifindex=ifindex; sa.sll_halen=6; memcpy(sa.sll_addr,dst,6);
    return sendto(raw,frame,p-frame,0,(struct sockaddr *)&sa,sizeof(sa));
}

static void usage(const char *p)
{
    fprintf(stderr,"openipc-lldp %s\nUsage: %s [-i iface] [-n name] [-d desc] [-t ttl] [-r sec] [-q]\n",APP_VERSION,p);
}

int main(int argc, char **argv)
{
    char ifname[IFNAMSIZ] = DEFAULT_IFACE, name[256] = "", desc[384] = "";
    unsigned ttl=DEFAULT_TTL, interval=DEFAULT_INTERVAL; int q=0,opt,raw,io,ifindex; struct ifreq ifr; uint8_t mac[6];
    while ((opt=getopt(argc,argv,"i:n:d:t:r:qVh")) != -1) switch(opt) {
        case 'i': snprintf(ifname,sizeof(ifname),"%s",optarg); break;
        case 'n': snprintf(name,sizeof(name),"%s",optarg); break;
        case 'd': snprintf(desc,sizeof(desc),"%s",optarg); break;
        case 't': ttl=strtoul(optarg,NULL,10); if (!ttl || ttl>65535) return 2; break;
        case 'r': interval=strtoul(optarg,NULL,10); if (!interval) return 2; break;
        case 'q': q=1; break;
        case 'V': puts(APP_VERSION); return 0;
        default: usage(argv[0]); return opt=='h'?0:2;
    }
    if (!name[0] && gethostname(name,sizeof(name)-1)) snprintf(name,sizeof(name),"openipc-camera");
    if (!desc[0]) make_description(desc,sizeof(desc));

    raw=socket(AF_PACKET,SOCK_RAW,htons(LLDP_ETHERTYPE)); if(raw<0){perror("socket");return 1;}
    io=socket(AF_INET,SOCK_DGRAM,0); if(io<0){perror("ioctl socket");close(raw);return 1;}
    memset(&ifr,0,sizeof(ifr)); snprintf(ifr.ifr_name,sizeof(ifr.ifr_name),"%s",ifname);
    if(ioctl(io,SIOCGIFINDEX,&ifr)<0){perror("SIOCGIFINDEX");return 1;} ifindex=ifr.ifr_ifindex;
    if(ioctl(io,SIOCGIFHWADDR,&ifr)<0){perror("SIOCGIFHWADDR");return 1;} memcpy(mac,ifr.ifr_hwaddr.sa_data,6);

    signal(SIGINT,on_signal); signal(SIGTERM,on_signal); signal(SIGHUP,on_signal);
    if(!q) fprintf(stderr,"openipc-lldp %s: %s, name='%s', ttl=%u, interval=%us\n",APP_VERSION,ifname,name,ttl,interval);
    while(!stopping){
        if(send_lldp(raw,io,ifindex,ifname,mac,name,desc,ttl)<0) perror("sendto");
        for(unsigned i=0;i<interval && !stopping;i++) sleep(1);
    }
    send_lldp(raw,io,ifindex,ifname,mac,name,desc,0);
    close(io); close(raw); return 0;
}
