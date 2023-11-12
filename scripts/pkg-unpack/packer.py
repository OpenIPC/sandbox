#!/bin/python

import struct
import hashlib

PKG_SIG = 0x43484950
PKG_FMT = 0x1002
parts = ['boot.img', 'kernel.img', 'rootfs.img', 'ipc.img', 'update.zip']

def pkg_unpack(pkg_filename):
    data = bytearray(open(pkg_filename,'rb').read())
    head = struct.unpack('<7I', data[:28])
    crcs = struct.unpack('<40s40s40s40s40s', data[0x44:0x44+200])


    if head[0] != PKG_SIG:
        print("File signature error {head[0]:x}!={PKG_SIG:x}.")
        return

    print(f"Signature=0x{head[0]:x}, File format version=0x{head[1]:x}")

    pos = 0x200 # data start
    for e in zip(parts, head[2:], crcs):
        crc = e[2].decode('UTF8').split('\0')[0] # asciiz MD5
        print(f"{e[0]:15} len:{e[1]:8} MD5(+salt 'IPCAM'):{crc}")

        if e[1]: # there is data
            d = data[pos:pos+e[1]]

            # unscramble zip ile
            if e[0] == 'update.zip':
                d = d.replace(b'PK\x03\x07', b'PK\x03\x04')
                d = d.replace(b'PK\x01\x08', b'PK\x01\x02')
                d = d.replace(b'PK\x05\x09', b'PK\x05\x06')

            with open(e[0], 'wb') as f:
                f.write(d)

            pos += e[1]

def pkg_pack(pkg_filename):
    head = [PKG_SIG, PKG_FMT]
    crcs = bytearray()
    data = bytearray()

    for n in parts:
        d = None
        try:
            d = bytearray(open(n,'rb').read())
        except:
            crcs += b'\0' * 40;
            head.append(0)
            continue


        head.append(len(d))
        crcs += hashlib.md5(d + b'IPCAM').hexdigest().encode('UTF-8')
        crcs += b'\0' * 8

        # scramble zip ile
        if n == 'update.zip':
            d = d.replace(b'PK\x03\x04', b'PK\x03\x07')
            d = d.replace(b'PK\x01\x02', b'PK\x01\x08')
            d = d.replace(b'PK\x05\x06', b'PK\x05\x09')

        data += d

    with open(pkg_filename, 'wb') as f:
        # combine header data
        hd = struct.pack('<7I', *head)
        hd += b'IPCAM'
        hd += b'\0' * (0x44 - len(hd))
        hd += crcs
        hd += b'\0' * (0x200 - len(hd))

        f.write(hd)
        f.write(data)


pkg_unpack('Hi16EV200HX_V20.1.31.15.19-20200813.pkg')
pkg_pack('test.pkg')
