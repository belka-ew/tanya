/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/posix/ioctl.d,
 *                 tanya/sys/posix/ioctl.d)
 */
module tanya.sys.posix.ioctl;

version (TanyaNative):

enum
{
    SIOCADDRT = 0x890B, // Add routing table entry.
    SIOCDELRT = 0x890C, // Delete routing table entry.
    SIOCRTMSG = 0x890D, // Call to routing system.

    SIOCGIFNAME = 0x8910, // Get iface name.
    SIOCSIFLINK = 0x8911, // Set iface channel.
    SIOCGIFCONF = 0x8912, // Get iface list.
    SIOCGIFFLAGS = 0x8913, // Get flags.
    SIOCSIFFLAGS = 0x8914, // Set flags.
    SIOCGIFADDR = 0x8915, // Get PA address.
    SIOCSIFADDR = 0x8916, // Set PA address.
    SIOCGIFDSTADDR = 0x8917, // Get remote PA address.
    SIOCSIFDSTADDR = 0x8918, // Set remote PA address.
    SIOCGIFBRDADDR = 0x8919, // Get broadcast PA address.
    SIOCSIFBRDADDR = 0x891a, // Set broadcast PA address.
    SIOCGIFNETMASK = 0x891b, // Get network PA mask.
    SIOCSIFNETMASK = 0x891c, // Set network PA mask.
    SIOCGIFMETRIC = 0x891d, // Get metric.
    SIOCSIFMETRIC = 0x891e, // Set metric.
    SIOCGIFMEM = 0x891f, // Get memory address (BSD).
    SIOCSIFMEM = 0x8920, // Set memory address (BSD).
    SIOCGIFMTU = 0x8921, // Get MTU size.
    SIOCSIFMTU = 0x8922, // Set MTU size.
    SIOCSIFNAME = 0x8923, // Set interface name.
    SIOCSIFHWADDR = 0x8924, // Set hardware address.
    SIOCGIFENCAP = 0x8925, // Get/set encapsulations.
    SIOCSIFENCAP = 0x8926,
    SIOCGIFHWADDR = 0x8927, // Get hardware address.
    SIOCGIFSLAVE = 0x8929, // Driver slaving support.
    SIOCSIFSLAVE = 0x8930,
    SIOCADDMULTI = 0x8931, // Multicast address lists.
    SIOCDELMULTI = 0x8932,
    SIOCGIFINDEX = 0x8933, // Name -> if_index mapping.
    SIOGIFINDEX = SIOCGIFINDEX, // Misprint compatibility.
    SIOCSIFPFLAGS = 0x8934, // Set/get extended flags set.
    SIOCGIFPFLAGS = 0x8935,
    SIOCDIFADDR = 0x8936, // Delete PA address.
    SIOCSIFHWBROADCAST = 0x8937, // Set hardware broadcast address.
    SIOCGIFCOUNT = 0x8938, // Get number of devices.

    SIOCGIFBR = 0x8940, // Bridging support.
    SIOCSIFBR = 0x8941, // Set bridging options.

    SIOCGIFTXQLEN = 0x8942, // Get the tx queue length.
    SIOCSIFTXQLEN = 0x8943, // Set the tx queue length.

    SIOCDARP = 0x8953, // Delete ARP table entry.
    SIOCGARP = 0x8954, // Get ARP table entry.
    SIOCSARP = 0x8955, // Set ARP table entry.

    SIOCDRARP = 0x8960, // Delete RARP table entry.
    SIOCGRARP = 0x8961, // Get RARP table entry.
    SIOCSRARP = 0x8962, // Set RARP table entry.

    SIOCGIFMAP = 0x8970, // Get device parameters.
    SIOCSIFMAP = 0x8971, // Set device parameters.

    SIOCADDDLCI = 0x8980, // Create new DLCI device.
    SIOCDELDLCI = 0x8981, // Delete DLCI device.
}
