/* Host-only regression checks; no network traffic or privileges required. */
#define _GNU_SOURCE
#include <assert.h>
#define main advertiser_main
#define sendto capture_sendto
#include "../openipc-lldp.c"
#undef main
#undef sendto

static uint8_t captured[LLDP_FRAME_MAX];
static size_t captured_len;
ssize_t capture_sendto(int fd, const void *buf, size_t len, int flags,
                      const struct sockaddr *addr, socklen_t addrlen)
{
    (void)fd; (void)flags; (void)addr; (void)addrlen;
    memcpy(captured, buf, len);
    captured_len = len;
    return (ssize_t)len;
}

int main(void)
{
    unsigned n;
    const char *bad[] = {"", "-1", "+1", " 1", "1x", "0", "65536",
                         "184467440737095516160"};
    for (size_t i = 0; i < sizeof(bad)/sizeof(bad[0]); i++)
        assert(parse_unsigned(bad[i], 65535, &n) == -1);
    assert(parse_unsigned("65535", 65535, &n) == 0 && n == 65535);
    assert(mau_from_link(100, DUPLEX_UNKNOWN) == 0);
    assert(mau_from_link(100, DUPLEX_FULL) == 16);
    assert(pmd_from_ethtool(ADVERTISED_Pause | ADVERTISED_Asym_Pause) == 0x00c0);
    assert(pmd_from_ethtool(ADVERTISED_10baseT_Half | ADVERTISED_10baseT_Full |
                           ADVERTISED_100baseT_Half | ADVERTISED_100baseT_Full) == 0x6c00);

    uint8_t buf[4], *p = buf;
    assert(put_tlv(&p, buf + sizeof(buf), 3, "ab", 2) == 0);
    assert(buf[0] == 6 && buf[1] == 2);
    assert(put_tlv(&p, buf + sizeof(buf), 0, NULL, 0) == -1);
    assert(p == buf + 4);

    const uint8_t mac[6] = {2, 0, 0, 0, 0, 1};
    assert(send_lldp(-1, -1, 1, "eth0", mac, "camera", "test", 0) == ETH_ZLEN);
    size_t off = ETH_HLEN;
    const unsigned types[] = {1, 2, 3, 0};
    for (size_t i = 0; i < 4; i++) {
        unsigned h = (captured[off] << 8) | captured[off + 1];
        assert((h >> 9) == types[i]);
        if (types[i] == 3) {
            assert((h & 511) == 2);
            assert(captured[off + 2] == 0 && captured[off + 3] == 0);
        }
        off += 2 + (h & 511);
    }
    while (off < captured_len) assert(captured[off++] == 0);
    puts("LLDP regression checks passed");
    return 0;
}
