#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <limits.h>
#include <linux/ethtool.h>
#include <net/if_arp.h>
#include <linux/if_ether.h>
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

#define APP_VERSION "0.2.2"
#define LLDP_ETHERTYPE 0x88cc
#define DEFAULT_IFACE "eth0"
#define DEFAULT_TTL 120
#define DEFAULT_INTERVAL 30
#define LLDP_FRAME_MAX 1500

static volatile sig_atomic_t stopping;

static void on_signal(int sig) { (void)sig; stopping = 1; }

/*
 * Append one LLDP TLV safely.
 *
 * LLDP TLV length is 9 bits, so a single value cannot exceed 511 bytes.
 * Return 0 on success, -1 if the TLV is invalid or would exceed the frame.
 */
static int put_tlv(uint8_t **pp, const uint8_t *end, uint8_t type,
                   const void *data, size_t len)
{
    uint8_t *p = *pp;
    uint16_t hdr;

    if (type > 127 || len > 511 || (size_t)(end - p) < len + 2)
        return -1;

    hdr = htons(((uint16_t)type << 9) | (uint16_t)len);
    memcpy(p, &hdr, 2);
    p += 2;

    if (len) {
        memcpy(p, data, len);
        p += len;
    }

    *pp = p;
    return 0;
}

static int parse_unsigned(const char *s, unsigned max, unsigned *out)
{
    char *end;
    unsigned long value;

    if (*s < '0' || *s > '9') return -1;
    errno = 0;
    value = strtoul(s, &end, 10);
    if (errno || *end || !value || value > max) return -1;
    *out = (unsigned)value;
    return 0;
}

static void trim(char *s)
{
    size_t n;
    while (*s == ' ' || *s == '\t') memmove(s, s + 1, strlen(s));
    n = strlen(s);
    while (n && (s[n-1] == '\n' || s[n-1] == '\r' || s[n-1] == ' ' || s[n-1] == '\t'))
        s[--n] = 0;
    if (n >= 2 && ((s[0] == '"' && s[n-1] == '"') || (s[0] == '\'' && s[n-1] == '\''))) {
        memmove(s, s + 1, n - 2);
        s[n - 2] = 0;
    }
}

static int osrel(const char *key, char *out, size_t outlen)
{
    FILE *f = fopen("/etc/os-release", "r");
    char line[384];
    size_t k = strlen(key);

    if (!f) return -1;

    while (fgets(line, sizeof(line), f)) {
        if (!strncmp(line, key, k) && line[k] == '=') {
            snprintf(out, outlen, "%s", line + k + 1);
            trim(out);
            fclose(f);
            return 0;
        }
    }

    fclose(f);
    return -1;
}

static void make_description(char *out, size_t n)
{
    char v[64] = "", p[96] = "", b[128] = "";
    struct utsname u;
    char full[384];

    osrel("OPENIPC_VERSION", v, sizeof(v));
    osrel("BUILD_PLATFORM", p, sizeof(p));
    osrel("BUILD_ID", b, sizeof(b));

    if (v[0] || p[0] || b[0]) {
        snprintf(full, sizeof(full), "OpenIPC%s%s%s%s%s%s",
                 v[0] ? " " : "", v,
                 p[0] ? " | " : "", p,
                 b[0] ? " | " : "", b);
        size_t len = strnlen(full, n - 1);
        memcpy(out, full, len);
        out[len] = 0;
    } else if (!uname(&u)) {
        snprintf(out, n, "OpenIPC | Linux %s %s", u.release, u.machine);
    } else {
        snprintf(out, n, "OpenIPC camera");
    }
}

static int get_ipv4(int io, const char *ifname, struct in_addr *addr)
{
    struct ifreq ifr;

    memset(&ifr, 0, sizeof(ifr));
    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);

    if (ioctl(io, SIOCGIFADDR, &ifr) < 0)
        return -1;

    *addr = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr;
    return 0;
}

static int get_mfs(int io, const char *ifname, uint16_t *mfs)
{
    struct ifreq ifr;
    unsigned long v;

    memset(&ifr, 0, sizeof(ifr));
    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);

    if (ioctl(io, SIOCGIFMTU, &ifr) < 0 || ifr.ifr_mtu < 0)
        return -1;

    /*
     * SIOCGIFMTU reports the layer-3 payload MTU.
     * IEEE 802.3 Maximum Frame Size describes the complete Ethernet frame:
     * destination/source MAC + EtherType/length (14) + payload + FCS (4).
     * Preamble/SFD and inter-frame gap are not part of the MAC frame.
     */
    v = (unsigned long)ifr.ifr_mtu + ETH_HLEN + ETH_FCS_LEN;
    if (v > UINT16_MAX)
        return -1;

    *mfs = (uint16_t)v;
    return 0;
}

struct phy_info {
    int valid;
    uint8_t autoneg;        /* bit0 supported, bit1 enabled */
    uint16_t pmd;           /* RFC 3636 / IANA ifMauAutoNegCapBits */
    uint16_t mau;           /* operational MAU type */
};

static uint16_t pmd_from_ethtool(uint32_t a)
{
    uint16_t p = 0;

    /*
     * PMD Auto-Negotiation Advertised Capability field values.
     * These are the RFC 3636 / IANA ifMauAutoNegCapBits values used by
     * IEEE 802.3 LLDP MAC/PHY, not host bit indexes.
     */
#ifdef ADVERTISED_10baseT_Half
    if (a & ADVERTISED_10baseT_Half) p |= 0x4000;
#endif
#ifdef ADVERTISED_10baseT_Full
    if (a & ADVERTISED_10baseT_Full) p |= 0x2000;
#endif
#ifdef ADVERTISED_100baseT_Half
    if (a & ADVERTISED_100baseT_Half) p |= 0x0800;
#endif
#ifdef ADVERTISED_100baseT_Full
    if (a & ADVERTISED_100baseT_Full) p |= 0x0400;
#endif
#ifdef ADVERTISED_Pause
    if (a & ADVERTISED_Pause) p |= 0x0080;
#endif
#ifdef ADVERTISED_Asym_Pause
    if (a & ADVERTISED_Asym_Pause) p |= 0x0040;
#endif
#ifdef ADVERTISED_1000baseT_Half
    if (a & ADVERTISED_1000baseT_Half) p |= 0x0002;
#endif
#ifdef ADVERTISED_1000baseT_Full
    if (a & ADVERTISED_1000baseT_Full) p |= 0x0001;
#endif

    return p;
}

static uint16_t mau_from_link(unsigned speed, unsigned duplex)
{
    if (duplex != DUPLEX_HALF && duplex != DUPLEX_FULL) return 0;
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

    memset(&ifr, 0, sizeof(ifr));
    memset(&ecmd, 0, sizeof(ecmd));

    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);
    ecmd.cmd = ETHTOOL_GSET;
    ifr.ifr_data = (void *)&ecmd;

    if (ioctl(io, SIOCETHTOOL, &ifr) < 0)
        return pi;

    pi.valid = 1;

#ifdef SUPPORTED_Autoneg
    if (ecmd.supported & SUPPORTED_Autoneg)
        pi.autoneg |= 1;
#endif
    if (ecmd.autoneg == AUTONEG_ENABLE)
        pi.autoneg |= 2;

    /* Advertise exactly what the interface is currently advertising. */
    pi.pmd = pmd_from_ethtool(ecmd.advertising);
    pi.mau = mau_from_link(ethtool_cmd_speed(&ecmd), ecmd.duplex);

    return pi;
}

static int send_lldp(int raw, int io, int ifindex, const char *ifname,
                     const uint8_t mac[6], const char *name, const char *desc,
                     unsigned ttl)
{
    static const uint8_t dst[6] = {0x01,0x80,0xc2,0x00,0x00,0x0e};
    uint8_t frame[LLDP_FRAME_MAX], *p = frame;
    const uint8_t *end = frame + sizeof(frame);
    struct ethhdr *eth;
    struct sockaddr_ll sa;
    struct in_addr ip;
    struct phy_info phy;
    uint16_t mfs;

#define APPEND_TLV(type_, data_, len_) \
    do { \
        if (put_tlv(&p, end, (type_), (data_), (len_)) < 0) { \
            errno = EMSGSIZE; \
            return -1; \
        } \
    } while (0)

    if ((size_t)(end - p) < sizeof(struct ethhdr)) {
        errno = EMSGSIZE;
        return -1;
    }

    eth = (struct ethhdr *)p;
    memcpy(eth->h_dest, dst, 6);
    memcpy(eth->h_source, mac, 6);
    eth->h_proto = htons(LLDP_ETHERTYPE);
    p += sizeof(*eth);

    {
        uint8_t v[7] = {4};
        memcpy(v + 1, mac, 6);
        APPEND_TLV(1, v, sizeof(v));
    }

    {
        uint8_t v[1 + IFNAMSIZ];
        size_t l = strnlen(ifname, IFNAMSIZ - 1);
        v[0] = 5;
        memcpy(v + 1, ifname, l);
        APPEND_TLV(2, v, l + 1);
    }

    {
        uint16_t v = htons((uint16_t)ttl);
        APPEND_TLV(3, &v, sizeof(v));
    }

    if (!ttl) goto end_tlvs;

    APPEND_TLV(4, ifname, strlen(ifname));
    APPEND_TLV(5, name, strlen(name));
    APPEND_TLV(6, desc, strlen(desc));

    {
        uint16_t s = htons(0x0080), e = htons(0x0080);
        uint8_t v[4];
        memcpy(v, &s, 2);
        memcpy(v + 2, &e, 2);
        APPEND_TLV(7, v, sizeof(v));
    }

    if (ttl && get_ipv4(io, ifname, &ip) == 0) {
        uint8_t v[12], *m = v;
        uint32_t idx = htonl((uint32_t)ifindex);

        *m++ = 5; /* management address string length */
        *m++ = 1; /* IPv4 subtype */
        memcpy(m, &ip, 4); m += 4;
        *m++ = 2; /* ifIndex numbering subtype */
        memcpy(m, &idx, 4); m += 4;
        *m++ = 0; /* OID length */

        APPEND_TLV(8, v, (size_t)(m - v));
    }

    phy = get_phy(io, ifname);

    /* IEEE 802.3 MAC/PHY Configuration/Status TLV (OUI 00:12:0f, subtype 1). */
    if (ttl && phy.valid) {
        uint8_t v[9] = {0x00,0x12,0x0f,0x01,0,0,0,0,0};
        uint16_t pmd = htons(phy.pmd);
        uint16_t mau = htons(phy.mau);

        v[4] = phy.autoneg;
        memcpy(v + 5, &pmd, 2);
        memcpy(v + 7, &mau, 2);
        APPEND_TLV(127, v, sizeof(v));
    }

    /*
     * IEEE 802.3 Maximum Frame Size TLV (subtype 4).
     * This is independent of legacy ETHTOOL_GSET support.
     */
    if (ttl && get_mfs(io, ifname, &mfs) == 0) {
        uint8_t v[6] = {0x00,0x12,0x0f,0x04,0,0};
        uint16_t wire_mfs = htons(mfs);

        memcpy(v + 4, &wire_mfs, 2);
        APPEND_TLV(127, v, sizeof(v));
    }

end_tlvs:
    APPEND_TLV(0, NULL, 0);

    /* Raw packet sockets do not guarantee Ethernet minimum-frame padding. */
    while (p - frame < ETH_ZLEN) *p++ = 0;

    memset(&sa, 0, sizeof(sa));
    sa.sll_family = AF_PACKET;
    sa.sll_protocol = htons(LLDP_ETHERTYPE);
    sa.sll_ifindex = ifindex;
    sa.sll_halen = 6;
    memcpy(sa.sll_addr, dst, 6);

#undef APPEND_TLV

    return sendto(raw, frame, (size_t)(p - frame), 0,
                  (struct sockaddr *)&sa, sizeof(sa));
}

static void usage(const char *p)
{
    fprintf(stderr,
            "openipc-lldp %s\n"
            "Usage: %s [-i iface] [-n name] [-d desc] [-t ttl] [-r sec] [-q]\n",
            APP_VERSION, p);
}

int main(int argc, char **argv)
{
    char ifname[IFNAMSIZ] = DEFAULT_IFACE;
    char name[256 + 1] = "";
    char desc[256 + 1] = "";
    unsigned ttl = DEFAULT_TTL, interval = DEFAULT_INTERVAL;
    int q = 0, opt, raw, io, ifindex;
    struct ifreq ifr;
    uint8_t mac[6];

    while ((opt = getopt(argc, argv, "i:n:d:t:r:qVh")) != -1) {
        switch (opt) {
        case 'i':
            if (!*optarg || strlen(optarg) >= sizeof(ifname)) {
                fprintf(stderr, "Invalid interface name\n");
                return 2;
            }
            snprintf(ifname, sizeof(ifname), "%s", optarg);
            break;
        case 'n':
            if (strlen(optarg) >= sizeof(name)) {
                fprintf(stderr, "LLDP text must not exceed 256 bytes\n");
                return 2;
            }
            snprintf(name, sizeof(name), "%s", optarg);
            break;
        case 'd':
            if (strlen(optarg) >= sizeof(desc)) {
                fprintf(stderr, "LLDP text must not exceed 256 bytes\n");
                return 2;
            }
            snprintf(desc, sizeof(desc), "%s", optarg);
            break;
        case 't':
            if (parse_unsigned(optarg, UINT16_MAX, &ttl)) {
                fprintf(stderr, "Invalid TTL (expected 1..65535)\n");
                return 2;
            }
            break;
        case 'r':
            if (parse_unsigned(optarg, UINT_MAX, &interval)) {
                fprintf(stderr, "Invalid advertisement interval\n");
                return 2;
            }
            break;
        case 'q':
            q = 1;
            break;
        case 'V':
            puts(APP_VERSION);
            return 0;
        default:
            usage(argv[0]);
            return opt == 'h' ? 0 : 2;
        }
    }

    if (optind != argc) {
        usage(argv[0]);
        return 2;
    }

    if (!name[0] && gethostname(name, sizeof(name) - 1))
        snprintf(name, sizeof(name), "openipc-camera");

    if (!desc[0])
        make_description(desc, sizeof(desc));

    raw = socket(AF_PACKET, SOCK_RAW, 0);
    if (raw < 0) {
        perror("socket");
        return 1;
    }

    io = socket(AF_INET, SOCK_DGRAM, 0);
    if (io < 0) {
        perror("ioctl socket");
        close(raw);
        return 1;
    }

    memset(&ifr, 0, sizeof(ifr));
    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);

    if (ioctl(io, SIOCGIFINDEX, &ifr) < 0) {
        perror("SIOCGIFINDEX");
        close(io);
        close(raw);
        return 1;
    }
    ifindex = ifr.ifr_ifindex;

    if (ioctl(io, SIOCGIFHWADDR, &ifr) < 0) {
        perror("SIOCGIFHWADDR");
        close(io);
        close(raw);
        return 1;
    }
    if (ifr.ifr_hwaddr.sa_family != ARPHRD_ETHER) {
        fprintf(stderr, "%s is not an Ethernet interface\n", ifname);
        close(io);
        close(raw);
        return 1;
    }
    memcpy(mac, ifr.ifr_hwaddr.sa_data, 6);

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    signal(SIGHUP, on_signal);

    if (!q) {
        fprintf(stderr,
                "openipc-lldp %s: %s, name='%s', ttl=%u, interval=%us\n",
                APP_VERSION, ifname, name, ttl, interval);
    }

    while (!stopping) {
        if (send_lldp(raw, io, ifindex, ifname, mac, name, desc, ttl) < 0)
            perror("send_lldp");

        for (unsigned i = 0; i < interval && !stopping; i++)
            sleep(1);
    }

    /* Withdraw the neighbor immediately on a clean shutdown. */
    send_lldp(raw, io, ifindex, ifname, mac, name, desc, 0);

    close(io);
    close(raw);
    return 0;
}
