/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module provides $(D_PSYMBOL format) function that can convert different
 * data types to a $(D_PSYMBOL String) according to a specified format.
 *
 * Format string is a $(D_PSYMBOL string) which can contain placeholders for
 * arguments. Placeholder marker is `{}`, i.e. all occurrences of `{}` are
 * replaced by the arguments passed to $(D_PSYMBOL format). An argument will be
 * first converted to a string, then inserted into the resulting string instead
 * of the corresponding placeholder. The number of the placeholders and
 * arguments must match. The placeholders are replaced with the arguments in
 * the order arguments are passed to $(D_PSYMBOL format).
 *
 * To escape `{` or `}`, use `{{` and `}}` respectively. `{{` will be outputted
 * as a single `{`, `}}` - as a single `}`.
 *
 * To define the string representation for a custom data type (like
 * $(D_KEYWORD class) or $(D_KEYWORD struct)), `toString()`-function can be
 * implemented for that type. `toString()` should be $(D_KEYWORD const) and
 * accept exactly one argument: an output range for `const(char)[]`. It should
 * return the same output range, advanced after putting the corresponding value
 * into it. That is `toString()` signature should look like:
 *
 * ---
 * OR toString(OR)(OR range) const
 * if (isOutputRange!(OR, const(char)[]));
 * ---
 *
 * String conversions for the most built-in data types a also available.
 *
 * $(D_KEYWORD char), $(D_KEYWORD wchar) and $(D_KEYWORD dchar) ranges are
 * outputted as plain strings (without any delimiters between their elements).
 *
 * All floating point numbers are handled as $(D_KEYWORD double)s.
 *
 * More advanced formatting is currently not implemented.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/format/package.d,
 *                 tanya/format/package.d)
 */
module tanya.format;

import std.algorithm.comparison;
import std.ascii;
import tanya.container.string;
import tanya.math;
static import tanya.memory.op;
import tanya.meta.metafunction;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;
import tanya.typecons : Tuple;

// Returns the last part of buffer with converted number.
package(tanya) char[] integral2String(T)(T number, return ref char[21] buffer)
@trusted
if (isIntegral!T)
{
    // abs the integer.
    ulong n64 = number < 0 ? -cast(long) number : number;

    char* start = buffer[].ptr + buffer.sizeof - 1;

    while (true)
    {
        // Do in 32-bit chunks (avoid lots of 64-bit divides even with constant
        // denominators).
        char* o = start - 8;
        uint n;
        if (n64 >= 100000000)
        {
            n = n64 % 100000000;
            n64 /= 100000000;
        }
        else
        {
            n = cast(uint) n64;
            n64 = 0;
        }

        while (n)
        {
            *--start = cast(char) (n % 10) + '0';
            n /= 10;
        }
        // Ignore the leading zero if it was the last part of the integer.
        if (n64 == 0)
        {
            if ((start[0] == '0')
             && (start != (buffer[].ptr + buffer.sizeof -1)))
            {
                ++start;
            }
            break;
        }
        // Copy leading zeros if it wasn't the most significant part of the
        // integer.
        while (start != o)
        {
            *--start = '0';
        }
    }

    // Get the length that we have copied.
    uint l = cast(uint) ((buffer[].ptr + buffer.sizeof - 1) - start);
    if (l == 0)
    {
        *--start = '0';
        l = 1;
    }
    else if (number < 0) // Set the sign.
    {
        *--start = '-';
        ++l;
    }

    return buffer[$ - l - 1 .. $ - 1];
}

private int frexp(const double x) @nogc nothrow pure @safe
{
    const FloatBits!double bits = { x };
    const int biased = (bits.integral & 0x7fffffffffffffffUL) >> 52;

    if ((bits.integral << 1) == 0 || biased == 0x7ff) // 0, NaN of Infinity
    {
        return 0;
    }
    else if (biased == 0) // Subnormal, normalize the exponent
    {
        return frexp(x * 0x1p64) - 64;
    }

    return biased - 1022;
}

/*
 * Double-double high-precision floating point number.
 *
 * The first element is a base value corresponding to the nearest approximation
 * of the target $(D_PSYMBOL HP) value, and the second element is an offset
 * value corresponding to the difference between the target value and the base.
 * Thus, the $(D_PSYMBOL HP) value represented is the sum of the base and the
 * offset.
 */
private struct HP
{
    double base;
    double offset = 0.0;

    this(double base, double offset = 0.0) @nogc nothrow pure @safe
    {
        this.base = base;
        this.offset = offset;
    }

    void normalize() @nogc nothrow pure @safe
    {
        const double target = this.base + this.offset;
        this.offset -= target - this.base;
        this.base = target;
    }

    void multiplyBy10() @nogc nothrow pure @safe
    {
        const double h = 8 * this.base + 2 * this.base;
        const double l = 10 * this.offset;
        const double c = (h - 8 * this.base) - 2 * this.base;

        this.base = h;
        this.offset = l - c;

        normalize();
    }

    void divideBy10() @nogc nothrow pure @safe
    {
        const double h = this.base / 10.0;
        const double l = this.offset / 10.0;
        const double c = (this.base - 8.0 * h) - 2.0 * h;

        this.base = h;
        this.offset = l + c / 10.0;

        normalize();
    }

    HP opBinary(string op : "*")(const double value) const
    {
        HP factor1 = split(this.base);
        HP factor2 = split(value);

        const double base = this.base * value;
        const double offset = (factor1.base * factor2.base - base)
                            + factor1.base * factor2.offset
                            + factor1.offset * factor2.base
                            + factor1.offset * factor2.offset;

        return HP(base, this.offset * value + offset);
    }
}

/*
 * Splits a double into two FP numbers.
 */
private HP split(double x) @nogc nothrow pure @safe
{
    FloatBits!double bits = { x };
    bits.integral &= 0xfffffffff8000000UL;
    return HP(bits.floating , x - bits.floating);
}

private enum special = 0x7000;
private enum char period = '.';

// Error factor. Determines the width of the narrow and wide intervals.
private enum double epsilon = 8.78e-15;

private immutable HP[600] powersOf10 = [
    HP(1e308, -0x1.c2a3c3d855605p+966),
    HP(1e307, 0x1.cab0301fbbb2ep+963),
    HP(1e306, -0x1.c43fd98036a40p+960),
    HP(1e305, 0x1.3f266e198eabfp+959),
    HP(1e304, 0x1.fea3e35c17799p+955),
    HP(1e303, -0x1.167d4fed38558p+944),
    HP(1e302, -0x1.9a78643ff0f9dp+949),
    HP(1e301, -0x1.c3f3d399818fcp+945),
    HP(1e300, -0x1.698fdc7ace0cap+942),
    HP(1e299, -0x1.213fe39571a3bp+939),
    HP(1e298, 0x1.646693ddb093ap+935),
    HP(1e297, -0x1.f1eaf3a0fe277p+930),
    HP(1e296, 0x1.a4dda37f34ad3p+927),
    HP(1e295, 0x1.50b14f98f6f0fp+924),
    HP(1e294, -0x1.dfb9135c6a060p+922),
    HP(1e293, 0x1.b36bf082de619p+919),
    HP(1e292, -0x1.ea19fcba70c29p+913),
    HP(1e291, 0x1.3794670de972ap+912),
    HP(1e290, -0x1.6d22e0c1aba44p+909),
    HP(1e289, -0x1.241be701561d0p+906),
    HP(1e288, -0x1.ce31f3444e400p+899),
    HP(1e287, -0x1.c7d1cb86d4a00p+899),
    HP(1e286, -0x1.3fb6127154333p+895),
    HP(1e285, 0x1.33a97c177947ap+891),
    HP(1e284, -0x1.eb55ce5d02b02p+889),
    HP(1e283, 0x1.baa9e904c87fcp+885),
    HP(1e282, -0x1.0444df2f5f99cp+882),
    HP(1e281, -0x1.a06e31e565c2dp+878),
    HP(1e280, -0x1.4d24f4b7849bdp+875),
    HP(1e279, -0x1.d750c3c603afep+872),
    HP(1e278, 0x1.dab1f9f660802p+868),
    HP(1e277, -0x1.dd804d47f9974p+861),
    HP(1e276, -0x1.b1799d76cc7acp+862),
    HP(1e275, 0x1.0b9eb53a8f9dcp+859),
    HP(1e274, 0x1.a2e55dc872e4ap+856),
    HP(1e273, 0x1.d16efc73eb076p+852),
    HP(1e272, -0x1.beda693cdd93ap+849),
    HP(1e271, 0x1.00eadf0281f04p+846),
    HP(1e270, -0x1.9821ce62634c6p+842),
    HP(1e269, -0x1.468171e84f704p+839),
    HP(1e268, 0x1.28ca7cf2b4191p+835),
    HP(1e267, 0x1.dadd94b7868e9p+831),
    HP(1e266, -0x1.b74ebc39fac12p+828),
    HP(1e265, -0x1.7c85e4e3fde6dp+826),
    HP(1e264, -0x1.94096e39963e2p+822),
    HP(1e263, -0x1.d9b7c71ead93bp+817),
    HP(1e262, -0x1.7af96c188adc9p+814),
    HP(1e261, 0x1.4dce1d94b1071p+813),
    HP(1e260, -0x1.e9e96a454b27dp+809),
    HP(1e259, 0x1.ab4544955d79bp+806),
    HP(1e258, -0x1.109562bbb5383p+803),
    HP(1e257, -0x1.ceaad58bdd80cp+798),
    HP(1e256, -0x1.7222446fe4670p+795),
    HP(1e255, 0x1.c5f8be99f1e99p+790),
    HP(1e254, 0x1.f464f2eb96c85p+789),
    HP(1e253, 0x1.9050c2561239dp+786),
    HP(1e252, -0x1.f2f297bb249e8p+783),
    HP(1e251, -0x1.84b7592b6dca6p+779),
    HP(1e250, 0x1.fc3a1f1074f7ap+776),
    HP(1e249, 0x1.9694e5a6c3f95p+773),
    HP(1e248, -0x1.75782a28600aap+769),
    HP(1e247, 0x1.3b9fde4619910p+766),
    HP(1e246, -0x1.69e6816185258p+763),
    HP(1e245, -0x1.763d9bcf3b6f4p+759),
    HP(1e244, -0x1.f831497295f2ap+756),
    HP(1e243, -0x1.935aa12877f54p+753),
    HP(1e242, -0x1.b89101da59887p+749),
    HP(1e241, -0x1.6074017b7ad39p+746),
    HP(1e240, -0x1.34a66b24bc3eap+741),
    HP(1e239, 0x1.455c215ed2ceep+737),
    HP(1e238, -0x1.58872c86a2a36p+736),
    HP(1e237, 0x1.52c70f944ab07p+733),
    HP(1e236, -0x1.e1f4b3df887f4p+729),
    HP(1e235, -0x1.81908fe606cc3p+726),
    HP(1e234, -0x1.9e9b661348f3dp+721),
    HP(1e233, 0x1.e783ae56f8d68p+718),
    HP(1e232, -0x1.a364ed76cfaa3p+716),
    HP(1e231, -0x1.4f83f12bd954fp+713),
    HP(1e230, -0x1.d9365a897aaa5p+710),
    HP(1e229, 0x1.f07b792044482p+703),
    HP(1e228, 0x1.cb3f8c1cd3a0dp+703),
    HP(1e227, -0x1.c3cd298289e5bp+700),
    HP(1e226, 0x1.2d1e23fbf02a0p+696),
    HP(1e225, 0x1.bdb1b66326880p+693),
    HP(1e224, 0x1.2f82bd6b70d99p+689),
    HP(1e223, -0x1.73976876d8eb8p+686),
    HP(1e222, -0x1.2945ed2be0bc6p+683),
    HP(1e221, -0x1.dba31513012d7p+679),
    HP(1e220, 0x1.d172257324207p+672),
    HP(1e219, 0x1.c82503beb6d00p+672),
    HP(1e218, -0x1.aff131b3b6dffp+670),
    HP(1e217, 0x1.4ce47d46db666p+666),
    HP(1e216, -0x1.1e926ac1d428ep+662),
    HP(1e215, 0x1.f3c56ee5ab22dp+660),
    HP(1e214, 0x1.8608b16f7837bp+656),
    HP(1e213, 0x1.ace89e3180b25p+651),
    HP(1e212, 0x1.ef61b93d19bd4p+650),
    HP(1e211, 0x1.7f02c1fb5c620p+646),
    HP(1e210, 0x1.ff3567fc49e80p+643),
    HP(1e209, -0x1.9a3baccfc4dffp+640),
    HP(1e208, 0x1.45a7709a56ccdp+635),
    HP(1e207, -0x1.17569fc243ae0p+633),
    HP(1e206, -0x1.bef0ff9d39167p+629),
    HP(1e205, -0x1.318198fb8e8a5p+625),
    HP(1e204, 0x1.4a63d8071bef6p+621),
    HP(1e203, 0x1.084fe005aff2bp+618),
    HP(1e202, 0x1.ce76600123308p+617),
    HP(1e201, -0x1.1c0f6664947f2p+613),
    HP(1e200, 0x1.6cb428f8ac016p+609),
    HP(1e199, -0x1.d484bc6954cc3p+607),
    HP(1e198, -0x1.0e758e1ddc272p+602),
    HP(1e197, 0x1.2d6a93f40e56bp+600),
    HP(1e196, 0x1.e2441fece3bdfp+596),
    HP(1e195, 0x1.6a06997b05fccp+592),
    HP(1e194, 0x1.5d9c3d6468cb8p+590),
    HP(1e193, -0x1.4eb6354945c39p+587),
    HP(1e192, -0x1.4abd220ed605cp+583),
    HP(1e191, -0x1.d5641b3f119e3p+580),
    HP(1e190, -0x1.778348ff414b5p+577),
    HP(1e189, -0x1.7e70e99737579p+572),
    HP(1e188, -0x1.31f3ee1292ac7p+569),
    HP(1e187, 0x1.ec04d3f892216p+567),
    HP(1e186, 0x1.59a90cb506d15p+562),
    HP(1e185, 0x1.14873d5d9f0ddp+559),
    HP(1e184, -0x1.78c1376a34b69p+555),
    HP(1e183, 0x1.cfb2b6a251508p+553),
    HP(1e182, -0x1.c03dd44af225fp+550),
    HP(1e181, 0x1.cc9b562a717b3p+547),
    HP(1e180, -0x1.48eaa556c351bp+541),
    HP(1e179, 0x1.16088aaa1845bp+539),
    HP(1e178, -0x1.2a62fbbbf64a8p+537),
    HP(1e177, -0x1.0f464b195b767p+531),
    HP(1e176, -0x1.b20a11c22bf0cp+527),
    HP(1e175, 0x1.6e32316c9534bp+527),
    HP(1e174, -0x1.4171720f88a29p+524),
    HP(1e173, -0x1.a2d60d303743fp+518),
    HP(1e172, -0x1.ed5e02a33e40cp+517),
    HP(1e171, 0x1.b769956135febp+513),
    HP(1e170, -0x1.06debbb23b343p+510),
    HP(1e169, 0x1.941a9d0b03d63p+507),
    HP(1e168, 0x1.43487da269782p+504),
    HP(1e167, -0x1.2df26a2f573fbp+500),
    HP(1e166, 0x1.74d7ab0d53cd0p+497),
    HP(1e165, 0x1.f712ef3ddca40p+494),
    HP(1e164, -0x1.c9035a0712651p+485),
    HP(1e163, 0x1.8e2cb7596c571p+487),
    HP(1e162, 0x1.3e8a2c4789df4p+484),
    HP(1e161, -0x1.358952c0bd012p+480),
    HP(1e160, -0x1.56a2119e533acp+474),
    HP(1e159, 0x1.775631702ae08p+474),
    HP(1e158, 0x1.8bbd1be6ab00dp+470),
    HP(1e157, 0x1.bf29f2e22335dp+465),
    HP(1e156, 0x1.65bb28b4e8f7ep+462),
    HP(1e155, -0x1.eda91756b019fp+457),
    HP(1e154, -0x1.fc5504aaf0053p+456),
    HP(1e153, 0x1.7797bb9ffdecbp+446),
    HP(1e152, -0x1.9740a6d3ccd01p+450),
    HP(1e151, -0x1.e40215d8f5cd2p+445),
    HP(1e150, 0x1.affe54ec0828ap+442),
    HP(1e149, -0x1.b99a446e6322fp+440),
    HP(1e148, -0x1.614836beb5b58p+437),
    HP(1e147, 0x1.fbe5b73754216p+432),
    HP(1e146, 0x1.326124a4aa6d1p+431),
    HP(1e145, 0x1.426db7510f86fp+425),
    HP(1e144, -0x1.18a0e9df93639p+423),
    HP(1e143, -0x1.c1017632856c2p+419),
    HP(1e142, -0x1.8066fc14355e7p+417),
    HP(1e141, -0x1.9ae326a7112e5p+412),
    HP(1e140, -0x1.1efa3aee36a2dp+411),
    HP(1e139, -0x1.fcba562d7ba2cp+406),
    HP(1e138, -0x1.96fb782462e89p+403),
    HP(1e137, -0x1.4595f9b6b586ep+400),
    HP(1e136, -0x1.d144c7c55e058p+397),
    HP(1e135, 0x1.e45ec05dcff72p+393),
    HP(1e134, 0x1.8e8c4cf2532fap+391),
    HP(1e133, -0x1.6b0bd69229010p+386),
    HP(1e132, 0x1.dca6eaf916630p+381),
    HP(1e131, 0x1.c943e44c1bd6bp+381),
    HP(1e130, -0x1.f12cf91fd3754p+377),
    HP(1e129, 0x1.7b80b0047445dp+369),
    HP(1e128, -0x1.901cc86649e4ap+371),
    HP(1e127, 0x1.7fd1f28f89c55p+367),
    HP(1e126, 0x1.ffdb2872d49dep+364),
    HP(1e125, 0x1.997c205bdd4b1p+361),
    HP(1e124, 0x1.c26033c62ede9p+357),
    HP(1e123, 0x1.370052d6b1641p+353),
    HP(1e122, -0x1.4199150ee42c9p+349),
    HP(1e121, -0x1.4d706ed2c1ab7p+347),
    HP(1e120, 0x1.1db281e1fd541p+343),
    HP(1e119, 0x1.3f1433f3feee6p+341),
    HP(1e118, 0x1.31b9ecb997e3ep+337),
    HP(1e117, -0x1.71d1a90520167p+334),
    HP(1e116, -0x1.6c38834399e18p+329),
    HP(1e115, -0x1.23606902e1813p+326),
    HP(1e114, -0x1.d233db37cf353p+322),
    HP(1e113, -0x1.74f648f97290fp+319),
    HP(1e112, 0x1.4f01f167b5e30p+318),
    HP(1e111, 0x1.4b364f0c56380p+314),
    HP(1e110, -0x1.2142b4b90fa66p+310),
    HP(1e109, 0x1.6462120b1a28fp+306),
    HP(1e108, -0x1.0b0bf8c85bef9p+304),
    HP(1e107, 0x1.87ecd8590680ap+300),
    HP(1e106, -0x1.c9a1430f96ffbp+298),
    HP(1e105, 0x1.f09794b3db339p+294),
    HP(1e104, -0x1.8a712136e13d3p+286),
    HP(1e103, -0x1.3b8db42be7642p+283),
    HP(1e102, 0x1.7a0b6dfb9c0f9p+283),
    HP(1e101, 0x1.2e6f8b2fb00c7p+280),
    HP(1e100, -0x1.4f4d87b3b31f4p+276),
    HP(1e99, 0x1.137a9684eb8d1p+274),
    HP(1e98, 0x1.f2a8a6e45ae8ep+266),
    HP(1e97, -0x1.8d222f071753cp+268),
    HP(1e96, -0x1.ae9d180b58860p+264),
    HP(1e95, -0x1.1761c012273cdp+260),
    HP(1e94, -0x1.bf02cce9d8616p+256),
    HP(1e93, -0x1.7f9ab85d89c08p+254),
    HP(1e92, -0x1.32e22d17a166dp+251),
    HP(1e91, -0x1.c24e8a794debep+248),
    HP(1e90, 0x1.2f8255a450203p+244),
    HP(1e89, 0x1.300ef0e867347p+238),
    HP(1e88, 0x1.d6696361ae3dbp+237),
    HP(1e87, 0x1.78544f8158315p+234),
    HP(1e86, -0x1.b22567fbb2954p+229),
    HP(1e85, -0x1.5b511ffc8eddcp+226),
    HP(1e84, -0x1.12436ccc1c92cp+225),
    HP(1e83, -0x1.d40af5c05b6f3p+220),
    HP(1e82, 0x1.bcc40832ea0d6p+217),
    HP(1e81, 0x1.7eb4d0145d9efp+215),
    HP(1e80, -0x1.08f322e84da10p+204),
    HP(1e79, 0x1.9649c2c37f079p+207),
    HP(1e78, -0x1.52472a5b364e1p+202),
    HP(1e77, 0x1.1249ef0eb713fp+200),
    HP(1e76, -0x1.2be26d2d505e6p+198),
    HP(1e75, 0x1.767e0f0ef2e7ap+195),
    HP(1e74, 0x1.8a634b4b1e3f7p+191),
    HP(1e73, 0x1.bad75756c7317p+186),
    HP(1e72, 0x1.255e44aaf4a37p+185),
    HP(1e71, -0x1.5dcf9221abc73p+181),
    HP(1e70, -0x1.e4a60e815638fp+178),
    HP(1e69, -0x1.83b80b9aab60cp+175),
    HP(1e68, 0x1.93a653d55431fp+171),
    HP(1e67, 0x1.d87aa5ddda397p+166),
    HP(1e66, 0x1.2b4bbac5f871ep+165),
    HP(1e65, 0x1.1517de8c9c728p+159),
    HP(1e64, -0x1.2ac340948e389p+157),
    HP(1e63, -0x1.444e19d505b03p+155),
    HP(1e62, -0x1.3a168fbb3c4d2p+151),
    HP(1e61, 0x1.6b21269d695bdp+148),
    HP(1e60, 0x1.2280ebb121164p+145),
    HP(1e59, 0x1.0401791b6823ap+141),
    HP(1e58, 0x1.9ccdfa7c534fbp+138),
    HP(1e57, -0x1.1c28046956f36p+135),
    HP(1e56, -0x1.b020038778c2bp+132),
    HP(1e55, -0x1.3400169638117p+126),
    HP(1e54, -0x1.d73337b7a4d04p+125),
    HP(1e53, 0x1.051e9b68adfe1p+119),
    HP(1e52, 0x1.a1ca924116635p+115),
    HP(1e51, 0x1.4e3ba83411e91p+112),
    HP(1e50, -0x1.782d3bfacb024p+112),
    HP(1e49, 0x1.a61e066ebb2f8p+108),
    HP(1e48, -0x1.14b4c7a76a405p+105),
    HP(1e47, -0x1.babad90bdd33cp+101),
    HP(1e46, 0x1.bb542c80deb48p+95),
    HP(1e45, 0x1.c5eed14016454p+95),
    HP(1e44, -0x1.c80dbeffee2f0p+92),
    HP(1e43, -0x1.cd24c665f4600p+86),
    HP(1e42, -0x1.29075ae130e00p+85),
    HP(1e41, -0x1.069578d46c000p+79),
    HP(1e40, -0x1.0151182a7c000p+78),
    HP(1e39, 0x1.988becaad0000p+75),
    HP(1e38, 0x1.e826288900000p+70),
    HP(1e37, 0x1.900f436a00000p+68),
    HP(1e36, -0x1.265a307800000p+65),
    HP(1e35, 0x1.5c3c7f4000000p+61),
    HP(1e34, 0x1.e363990000000p+58),
    HP(1e33, 0x1.82b6140000000p+55),
    HP(1e32, -0x1.3107f00000000p+52),
    HP(1e31, 0x1.4b26800000000p+48),
    HP(1e30, -0x1.215c000000000p+44),
    HP(1e29, 0x1.f2a8000000000p+42),
    HP(1e28, 0x1.8440000000000p+38),
    HP(1e27, -0x1.8c00000000000p+33),
    HP(1e26, -0x1.1c00000000000p+32),
    HP(1e25, -0x1.b000000000000p+29),
    HP(1e24, 0x1.0000000000000p+24),
    HP(1e23, 0x1.0000000000000p+23),
    HP(1e22, 0x0.0000000000000p+0),
    HP(1e21, 0x0.0000000000000p+0),
    HP(1e20, 0x0.0000000000000p+0),
    HP(1e19, 0x0.0000000000000p+0),
    HP(1e18, 0x0.0000000000000p+0),
    HP(1e17, 0x0.0000000000000p+0),
    HP(1e16, 0x0.0000000000000p+0),
    HP(1e15, 0x0.0000000000000p+0),
    HP(1e14, 0x0.0000000000000p+0),
    HP(1e13, 0x0.0000000000000p+0),
    HP(1e12, 0x0.0000000000000p+0),
    HP(1e11, 0x0.0000000000000p+0),
    HP(1e10, 0x0.0000000000000p+0),
    HP(1e9, 0x0.0000000000000p+0),
    HP(1e8, 0x0.0000000000000p+0),
    HP(1e7, 0x0.0000000000000p+0),
    HP(1e6, 0x0.0000000000000p+0),
    HP(1e5, 0x0.0000000000000p+0),
    HP(1e4, 0x0.0000000000000p+0),
    HP(1e3, 0x0.0000000000000p+0),
    HP(1e2, 0x0.0000000000000p+0),
    HP(1e1, 0x0.0000000000000p+0),
    HP(1e0, 0x0.0000000000000p+0),
    HP(1e-1, -0x1.9999999999999p-58),
    HP(1e-2, -0x1.eb851eb851eb8p-63),
    HP(1e-3, -0x1.89374bc6a7ef9p-66),
    HP(1e-4, -0x1.6a161e4f765fdp-68),
    HP(1e-5, -0x1.ee78183f91e64p-71),
    HP(1e-6, 0x1.b5a63f9a49c2cp-75),
    HP(1e-7, 0x1.5e1e99483b023p-78),
    HP(1e-8, -0x1.03023df2d4c94p-82),
    HP(1e-9, -0x1.34674bfabb83bp-84),
    HP(1e-10, -0x1.20a5465df8d2bp-88),
    HP(1e-11, 0x1.7f7bc7b4d28a9p-91),
    HP(1e-12, 0x1.97f27f0f6e885p-96),
    HP(1e-13, -0x1.ecd79a5a0df94p-99),
    HP(1e-14, 0x1.ea70909833de7p-107),
    HP(1e-15, -0x1.937831647f5a0p-104),
    HP(1e-16, 0x1.5b4c2ebe68798p-109),
    HP(1e-17, -0x1.db7b2080a3029p-111),
    HP(1e-18, -0x1.7c628066e8cedp-114),
    HP(1e-19, 0x1.a52b31e9e3d06p-119),
    HP(1e-20, 0x1.75447a5d8e535p-121),
    HP(1e-21, 0x1.f769fb7e0b75ep-124),
    HP(1e-22, -0x1.a7566d9cba769p-128),
    HP(1e-23, 0x1.13badb829e078p-131),
    HP(1e-24, 0x1.a96249354b393p-134),
    HP(1e-25, -0x1.5762be11213e0p-138),
    HP(1e-26, -0x1.12b564da80fe6p-141),
    HP(1e-27, -0x1.b788a15d9b30ap-145),
    HP(1e-28, 0x1.06c5e54eb70c4p-148),
    HP(1e-29, 0x1.9f04b7722c09dp-151),
    HP(1e-30, -0x1.e72f6d3e432b5p-154),
    HP(1e-31, -0x1.85bf8a9835bc4p-157),
    HP(1e-32, -0x1.a2cc10f3892d3p-161),
    HP(1e-33, -0x1.4f09a7293a8a9p-164),
    HP(1e-34, 0x1.5a5ead789df78p-167),
    HP(1e-35, -0x1.e1aa86c4e6d2ep-174),
    HP(1e-36, 0x1.696ef285e8eaep-174),
    HP(1e-37, -0x1.4540d794df441p-177),
    HP(1e-38, 0x1.2acb73de9ac64p-181),
    HP(1e-39, 0x1.bbd5f64baf050p-184),
    HP(1e-40, 0x1.631191d6259d9p-187),
    HP(1e-41, -0x1.72524ee484eb4p-194),
    HP(1e-42, -0x1.e3aa0fc74dc8ap-195),
    HP(1e-43, -0x1.8e44064fb8b6ap-197),
    HP(1e-44, 0x1.82c65c4d3edbbp-201),
    HP(1e-45, 0x1.a27ac0f72f8bfp-206),
    HP(1e-46, -0x1.e46a98d3d9f66p-209),
    HP(1e-47, 0x1.afaab8f01e6e1p-212),
    HP(1e-48, 0x1.595560c018580p-215),
    HP(1e-49, 0x1.56eef38009bcdp-217),
    HP(1e-50, -0x1.06d38332f4e12p-223),
    HP(1e-51, -0x1.a4859eb7ee350p-227),
    HP(1e-52, -0x1.506ae55ff1c40p-230),
    HP(1e-53, -0x1.10156113305a6p-231),
    HP(1e-54, -0x1.b355681eb3c3dp-235),
    HP(1e-55, 0x1.eaaa326eb4b42p-241),
    HP(1e-56, -0x1.6888948e87879p-241),
    HP(1e-57, 0x1.45f922c12d2d2p-244),
    HP(1e-58, -0x1.29a4953151516p-248),
    HP(1e-59, -0x1.dc3a884ee8823p-252),
    HP(1e-60, 0x1.b63792f412cb0p-255),
    HP(1e-61, -0x1.d4a0573cbdc3fp-258),
    HP(1e-62, -0x1.76e6ac3097cffp-261),
    HP(1e-63, -0x1.f8b889c079732p-264),
    HP(1e-64, 0x1.a53f2398d747bp-268),
    HP(1e-65, 0x1.754c74a3894fep-270),
    HP(1e-66, 0x1.775b0ed81dcc6p-275),
    HP(1e-67, 0x1.62f139233f1e9p-277),
    HP(1e-68, -0x1.4a7238b09a4dfp-280),
    HP(1e-69, 0x1.227c7218a2b67p-284),
    HP(1e-70, 0x1.b96c1ad4ef863p-291),
    HP(1e-71, 0x1.afabce243f2d1p-290),
    HP(1e-72, 0x1.1912e36d31e1cp-294),
    HP(1e-73, 0x1.40f1c575b1b05p-301),
    HP(1e-74, 0x1.b9b1c6f22b5e6p-301),
    HP(1e-75, 0x1.615b058e89185p-304),
    HP(1e-76, 0x1.e77c04720746ap-307),
    HP(1e-77, 0x1.85fcd05b39055p-310),
    HP(1e-78, 0x1.3290123e9aab2p-319),
    HP(1e-79, 0x1.ea801d30f7783p-323),
    HP(1e-80, 0x1.a5dccd879fc96p-321),
    HP(1e-81, 0x1.517d71394ca11p-324),
    HP(1e-82, 0x1.0dfdf42dd6e74p-327),
    HP(1e-83, -0x1.8336795041c11p-331),
    HP(1e-84, -0x1.35c52dd9ce341p-334),
    HP(1e-85, 0x1.4391503d1c797p-338),
    HP(1e-86, -0x1.e4f9131ac1690p-340),
    HP(1e-87, -0x1.431d09ef37b67p-345),
    HP(1e-88, 0x1.e52795a0501d6p-347),
    HP(1e-89, -0x1.c48d76ff7fd0fp-351),
    HP(1e-90, 0x1.7c76a00334606p-357),
    HP(1e-91, -0x1.4d81dfff5becbp-358),
    HP(1e-92, 0x1.1d96999aa01edp-362),
    HP(1e-93, 0x1.d2b7b85220062p-363),
    HP(1e-94, 0x1.5125f3b699a37p-367),
    HP(1e-95, 0x1.03aca57b853e4p-372),
    HP(1e-96, 0x1.cd88ede5810c7p-373),
    HP(1e-97, -0x1.1d8b502a64b8dp-377),
    HP(1e-98, 0x1.81f6f3114905bp-380),
    HP(1e-99, -0x1.9350296249875p-385),
    HP(1e-100, -0x1.42a68781d46c4p-388),
    HP(1e-101, -0x1.4ddc3633ee91bp-390),
    HP(1e-102, 0x1.5b4fd4a341250p-393),
    HP(1e-103, 0x1.5ee6210535080p-397),
    HP(1e-104, 0x1.e584e7375da00p-400),
    HP(1e-105, 0x1.6f3b0b8bc9001p-404),
    HP(1e-106, 0x1.f295a2d63a667p-407),
    HP(1e-107, -0x1.576fb7608f5aap-415),
    HP(1e-108, -0x1.aac595f8072aep-414),
    HP(1e-109, 0x1.10baece64f769p-419),
    HP(1e-110, -0x1.630dd09ebce84p-420),
    HP(1e-111, -0x1.e8d7da1897203p-423),
    HP(1e-112, 0x1.bea6a30bdaffap-427),
    HP(1e-113, 0x1.310a9e795e65dp-431),
    HP(1e-114, -0x1.1f955a35da3dap-433),
    HP(1e-115, -0x1.cc2229efc395dp-437),
    HP(1e-116, 0x1.4bf226ce4f740p-443),
    HP(1e-117, -0x1.5735f83d234f3p-444),
    HP(1e-118, 0x1.0e100c6afab47p-448),
    HP(1e-119, -0x1.831985bb3bac0p-452),
    HP(1e-120, 0x1.fd852e9d69dccp-455),
    HP(1e-121, 0x1.979dbee454b0ap-458),
    HP(1e-122, -0x1.c35a807177b95p-460),
    HP(1e-123, -0x1.6915338df9611p-463),
    HP(1e-124, 0x1.4588a38e6bb25p-466),
    HP(1e-125, -0x1.762f1c7081f10p-472),
    HP(1e-126, 0x1.4ec360b64c696p-473),
    HP(1e-127, -0x1.1b94320f85bdcp-477),
    HP(1e-128, -0x1.afa9c1a60497dp-480),
    HP(1e-129, 0x1.d9de9847fc535p-483),
    HP(1e-130, -0x1.b81ab96002f08p-486),
    HP(1e-131, 0x1.cc21c3ffed2fdp-492),
    HP(1e-132, 0x1.701b033324264p-495),
    HP(1e-133, -0x1.4ffa98f5c591fp-496),
    HP(1e-134, -0x1.4cc427efa2831p-500),
    HP(1e-135, -0x1.0a3686594ecf4p-503),
    HP(1e-136, -0x1.0573d5bb14ba8p-511),
    HP(1e-137, 0x1.7f746aa07ded5p-511),
    HP(1e-138, -0x1.cd04a22634077p-513),
    HP(1e-139, -0x1.480769d6b9a58p-517),
    HP(1e-140, 0x1.265a89dba3c3ep-521),
    HP(1e-141, -0x1.23dbc8db58180p-523),
    HP(1e-142, -0x1.d2f9415ef359ap-527),
    HP(1e-143, 0x1.bd9efee73d51ep-530),
    HP(1e-144, 0x1.647f32529774bp-533),
    HP(1e-145, 0x1.e9ff5b7545f6fp-536),
    HP(1e-146, -0x1.e0020e88b9b68p-541),
    HP(1e-147, 0x1.b3318df905079p-544),
    HP(1e-148, 0x1.7ae09f3068697p-546),
    HP(1e-149, 0x1.8935309ae7b7cp-551),
    HP(1e-150, -0x1.7c2297a9e74d6p-556),
    HP(1e-151, 0x1.739624089c11dp-556),
    HP(1e-152, -0x1.3d217cc5e98b5p-559),
    HP(1e-153, -0x1.2e9bfad642788p-563),
    HP(1e-154, 0x1.4f066ea92f3f3p-567),
    HP(1e-155, -0x1.1b28e88ae79aep-571),
    HP(1e-156, -0x1.3e105d045ca45p-573),
    HP(1e-157, 0x1.67f2e8c94f7c8p-576),
    HP(1e-158, -0x1.4670df5ef39c6p-579),
    HP(1e-159, 0x1.7060d0d3827d8p-585),
    HP(1e-160, 0x1.26b3da42cecadp-588),
    HP(1e-161, -0x1.23b80f187a154p-590),
    HP(1e-162, 0x1.7d065a52d1889p-593),
    HP(1e-163, 0x1.fd9eaea8a7a07p-596),
    HP(1e-164, 0x1.95cab10dd900bp-600),
    HP(1e-165, -0x1.53ddc96d49973p-605),
    HP(1e-166, -0x1.10c5f515db84ap-606),
    HP(1e-167, -0x1.ad654efc5a107p-614),
    HP(1e-168, -0x1.af11dd8c9e1a6p-613),
    HP(1e-169, -0x1.181c95adc9c3ep-617),
    HP(1e-170, 0x1.730576e9f0603p-621),
    HP(1e-171, 0x1.28d12bee59e68p-624),
    HP(1e-172, -0x1.22df88070f3d6p-626),
    HP(1e-173, -0x1.d165a671b1fbcp-630),
    HP(1e-174, 0x1.2a423d2859b47p-636),
    HP(1e-175, 0x1.dd36c8408f872p-640),
    HP(1e-176, 0x1.7dc56d0072d28p-643),
    HP(1e-177, 0x1.bfc6f14cd8484p-643),
    HP(1e-178, 0x1.6638c10a46a03p-646),
    HP(1e-179, -0x1.ec172fdf1dff5p-651),
    HP(1e-180, -0x1.89ac264c17ff7p-654),
    HP(1e-181, -0x1.6a44dc1e6fffcp-656),
    HP(1e-182, -0x1.21d0b01859996p-659),
    HP(1e-183, -0x1.b0d59ad147abfp-666),
    HP(1e-184, -0x1.c4e22914ed913p-666),
    HP(1e-185, 0x1.7a5892ad42c52p-672),
    HP(1e-186, 0x1.bf6f41de2046ep-672),
    HP(1e-187, -0x1.9d37f40bfe3a2p-678),
    HP(1e-188, 0x1.46f4cf30cd279p-679),
    HP(1e-189, -0x1.60d5c0a5c246bp-682),
    HP(1e-190, -0x1.35df3545a0e26p-687),
    HP(1e-191, -0x1.efcb886f67d09p-691),
    HP(1e-192, -0x1.fcc24e7cae5cep-692),
    HP(1e-193, -0x1.946a172de3c7ep-696),
    HP(1e-194, -0x1.daed16f93f4c6p-701),
    HP(1e-195, -0x1.f895d1650ca8ep-702),
    HP(1e-196, -0x1.8dbc823b47749p-706),
    HP(1e-197, 0x1.6da4c5a8b4f14p-711),
    HP(1e-198, 0x1.e2ba8dee8a96ap-712),
    HP(1e-199, 0x1.3bee92fb55154p-717),
    HP(1e-200, 0x1.f97db7f888220p-721),
    HP(1e-201, 0x1.31e5f1981b3a0p-722),
    HP(1e-202, -0x1.49c34a3fd46ffp-726),
    HP(1e-203, -0x1.07cf6e9976bffp-729),
    HP(1e-204, -0x1.8fe2eb7e2665bp-738),
    HP(1e-205, -0x1.3fe8bc64eb849p-741),
    HP(1e-206, -0x1.a9986fd1d8936p-740),
    HP(1e-207, 0x1.bc296cdf42f83p-742),
    HP(1e-208, -0x1.cfdedc1a30d30p-745),
    HP(1e-209, -0x1.4c97c6904e1e6p-749),
    HP(1e-210, -0x1.0a1305403e7ebp-752),
    HP(1e-211, -0x1.a1a8d10031fefp-755),
    HP(1e-212, 0x1.63beb199499b3p-759),
    HP(1e-213, 0x1.1c988e143ae29p-762),
    HP(1e-214, 0x1.b07a0b43624edp-765),
    HP(1e-215, -0x1.4c0987942f81dp-769),
    HP(1e-216, -0x1.09a139435934ap-772),
    HP(1e-217, -0x1.a14dc769142a2p-775),
    HP(1e-218, -0x1.02160bdb53769p-779),
    HP(1e-219, -0x1.9cf012f8858a9p-783),
    HP(1e-220, 0x1.3cffc34b2177bp-788),
    HP(1e-221, -0x1.1acce51525d01p-790),
    HP(1e-222, -0x1.3deb8ed542533p-792),
    HP(1e-223, 0x1.36871b7795e13p-796),
    HP(1e-224, -0x1.425b0740a9cadp-800),
    HP(1e-225, 0x1.18a8637fbc154p-802),
    HP(1e-226, 0x1.ad5382cc96776p-805),
    HP(1e-227, 0x1.e21f37adbd8bdp-809),
    HP(1e-228, -0x1.c967a6ea03ed0p-813),
    HP(1e-229, -0x1.83c30f90ce5edp-815),
    HP(1e-230, -0x1.9f9e7f4e16fe1p-819),
    HP(1e-231, 0x1.346b356c83394p-824),
    HP(1e-232, -0x1.1e3b843afeb5ep-826),
    HP(1e-233, 0x1.8169fc9d9aa1ap-829),
    HP(1e-234, 0x1.3454ca17aee7bp-832),
    HP(1e-235, 0x1.ed54768c4b0c6p-836),
    HP(1e-236, -0x1.a8893ac2f7294p-839),
    HP(1e-237, 0x1.17e27729b5e24p-844),
    HP(1e-238, 0x1.bfd0bea92303ap-848),
    HP(1e-239, -0x1.6cd18688afb2dp-848),
    HP(1e-240, 0x1.d6fb1e4a9a908p-853),
    HP(1e-241, 0x1.78c8e5087ba6dp-856),
    HP(1e-242, 0x1.2d6d8406c9524p-859),
    HP(1e-243, 0x1.22bce691d541ap-865),
    HP(1e-244, 0x1.b6ac7d74fbb9cp-865),
    HP(1e-245, 0x1.5ef0645d962e3p-868),
    HP(1e-246, 0x1.64b3d3c8f049fp-872),
    HP(1e-247, -0x1.f0f3c0b032469p-877),
    HP(1e-248, 0x1.a5a365d971612p-880),
    HP(1e-249, -0x1.bdbea40f6c3f8p-882),
    HP(1e-250, -0x1.6498833f89cc7p-885),
    HP(1e-251, -0x1.41e80a64ec27cp-890),
    HP(1e-252, 0x1.e5a32f0ad4bcep-892),
    HP(1e-253, -0x1.aeb0a72a89027p-895),
    HP(1e-254, 0x1.daa5e0aac5979p-898),
    HP(1e-255, -0x1.de1b2aa952051p-905),
    HP(1e-256, 0x1.39fa911155fefp-906),
    HP(1e-257, 0x1.f65db4e88997fp-910),
    HP(1e-258, 0x1.95bf1529d0a33p-912),
    HP(1e-259, -0x1.ee9a557825e3dp-915),
    HP(1e-260, 0x1.b56f773fc3603p-919),
    HP(1e-261, 0x1.224bf1ff9f006p-923),
    HP(1e-262, -0x1.62b9b0009b329p-927),
    HP(1e-263, -0x1.1bc7c0007c287p-930),
    HP(1e-264, -0x1.c60c66672d0d8p-934),
    HP(1e-265, 0x1.c7f6147a425b9p-937),
    HP(1e-266, 0x1.6cc4dd2e9b7c7p-940),
    HP(1e-267, 0x1.23d0b0f215fd2p-943),
    HP(1e-268, 0x1.4186ad2da2654p-945),
    HP(1e-269, 0x1.01388a8ae8510p-948),
    HP(1e-270, -0x1.97a588bb5917fp-952),
    HP(1e-271, 0x1.20485f6a1f200p-955),
    HP(1e-272, 0x1.b36d1921b2800p-958),
    HP(1e-273, -0x1.d6dbebe50acccp-961),
    HP(1e-274, 0x1.0ea0202b21eb8p-965),
    HP(1e-275, 0x1.a54ce688e7efap-968),
    HP(1e-276, -0x1.e228e12c13404p-971),
    HP(1e-277, 0x1.f916c90c8f323p-976),
    HP(1e-278, 0x1.96d5ea0506141p-978),
    HP(1e-279, -0x1.20ee77fbfb231p-981),
    HP(1e-280, 0x1.64e8d9a007c7cp-985),
    HP(1e-281, -0x1.f04a14664d809p-990),
    HP(1e-282, -0x1.8d081051d79a1p-993),
    HP(1e-283, 0x1.c7965fdf435bfp-995),
    HP(1e-284, -0x1.f3dc33679439ap-999),
    HP(1e-285, -0x1.94be7af63b4a4p-1001),
    HP(1e-286, -0x1.baca5e56c5439p-1005),
    HP(1e-287, -0x1.2add63be086c3p-1009),
    HP(1e-288, -0x1.44588e4c035e7p-1011),
    HP(1e-289, -0x1.b569f519af297p-1017),
    HP(1e-290, -0x1.f115310523084p-1018),
    HP(1e-291, 0x1.b177b191618c5p-1022),
];

private char[] errol1(const double value,
                      return ref char[512] digits,
                      out int exponent) @nogc nothrow pure @safe
{
    // Phase 1: Exponent Estimation
    exponent = cast(int) (frexp(value) * 0.30103);
    auto e = cast(size_t) (exponent + 307);

    if (e >= powersOf10.length)
    {
        exponent = powersOf10.length - 308;
        e = powersOf10.length - 1;
    }
    HP t = powersOf10[e];

    HP scaledInput = t * value;

    while (scaledInput.base > 10.0
        || (scaledInput.base == 10.0 && scaledInput.offset >= 0.0))
    {
        scaledInput.divideBy10();
        ++exponent;
        t.base /= 10.0;
    }
    while (scaledInput.base < 1.0
        || (scaledInput.base == 1.0 && scaledInput.offset < 0.0))
    {
        scaledInput.multiplyBy10();
        --exponent;
        t.base *= 10.0;
    }

    // Phase 2: Boundary Computation
    const double factor = t.base / (2.0 + epsilon);

    // Upper narrow boundary
    auto nMinus = HP(scaledInput.base, scaledInput.offset
                                     + (previous(value) - value) * factor);
    nMinus.normalize();

    // Lower narrow boundary
    auto nPlus = HP(scaledInput.base, scaledInput.offset
                                    + (next(value) - value) * factor);
    nPlus.normalize();

    // Phase 3: Exponent Rectification
    while (nPlus.base > 10.0 || (nPlus.base == 10.0 && nPlus.offset >= 0.0))
    {
        nMinus.divideBy10();
        nPlus.divideBy10();
        ++exponent;
    }
    while (nPlus.base < 1.0 || (nPlus.base == 1.0 && nPlus.offset < 0.0))
    {
        nMinus.multiplyBy10();
        nPlus.multiplyBy10();
        --exponent;
    }

    // get_digits_hp
    byte dMinus, dPlus;

    size_t i;
    do
    {
        dMinus = cast(byte) nMinus.base;
        dPlus = cast(byte) nPlus.base;

        if (nMinus.base == dMinus && nMinus.offset < 0.0)
        {
            --dMinus;
        }
        if (nPlus.base == dPlus && nPlus.offset < 0.0)
        {
            --dPlus;
        }

        if (dMinus != dPlus)
        {
            digits[i] = cast(char) ('0' + cast(ubyte) ((dPlus + dMinus) / 2.0 + 0.5));
            break;
        }
        else
        {
            digits[i] = cast(char) ('0' + cast(ubyte) dPlus);
        }
        ++i;

        nMinus.base -= dMinus;
        nPlus.base -= dPlus;
        nPlus.multiplyBy10();
        nMinus.multiplyBy10();
    }
    while (nPlus.base != 0.0 || nPlus.offset != 0.0);

    return digits[0 .. i + 1];
}

@nogc nothrow pure @safe unittest
{
    char[512] buf;
    int e;

    assert(errol1(18.51234334, buf, e) == "1851234334");
    assert(e == 2);

    assert(errol1(0.23432e304, buf, e) == "23432");
    assert(e == 304);
}

private struct uint128
{
    ulong[2] data;

    this(ulong upper, ulong lower) @nogc nothrow pure @safe
    {
        this.data[0] = upper;
        this.data[1] = lower;
    }

    this(ulong lower) @nogc nothrow pure @safe
    {
        this.data[1] = lower;
    }

    this(double value) @nogc nothrow pure @safe
    {
        FloatBits!double bits = { floating: value };
        const ulong unbiased = bits.integral >> 52;

        this((bits.integral & 0xfffffffffffff) + 0x10000000000000);
        this = this << (unbiased - 1075);
    }

    ref uint128 opUnary(string op : "++")()
    {
        ++this.data[1];
        if (this.data[1] == 0)
        {
            ++this.data[0];
        }
        return this;
    }

    uint128 opBinary(string op : "+")(uint128 rhs) const
    {
        uint128 result;
        result.data[1] = this.data[1] + rhs.data[1];
        result.data[0] = this.data[0] + rhs.data[0];

        if (result.data[1] < this.data[1])
        {
            ++result.data[0];
        }
        return result;
    }

    @nogc nothrow pure @safe unittest
    {
        assert((uint128() + uint128(1)) == uint128(1));
        assert((uint128(ulong.max) + uint128(1)) == uint128(1, 0));
    }

    uint128 opBinary(string op : "-")(uint128 rhs) const
    {
        uint128 result;
        result.data[1] = this.data[1] - rhs.data[1];
        result.data[0] = this.data[0] - rhs.data[0];

        if (result.data[1] > this.data[1])
        {
             --result.data[0];
        }
        return result;
    }

    ref uint128 opUnary(string op : "--")()
    {
        --this.data[1];
        if (this.data[1] == ulong.max)
        {
             --this.data[0];
        }
        return this;
    }

    @nogc nothrow pure @safe unittest
    {
        assert((uint128(1, 0) - uint128(1)) == uint128(ulong.max));
    }

    uint128 opBinary(string op : "&")(ulong rhs) const
    {
        return uint128(this.data[1] & rhs);
    }

    @nogc nothrow pure @safe unittest
    {
        assert((uint128(0xf0f0f, 0xf0f) & 0xf0f) == uint128(0xf0f));
    }

    uint128 opBinary(string op : ">>")(ulong shift) const
    {
        if (shift == 0)
        {
            return this;
        }
        else if (shift < 64)
        {
            const ulong lower = (this.data[0] << (64 - shift))
                              + (this.data[1] >> shift);
            return uint128(this.data[0] >> shift, lower);
        }
        else if (shift < 128)
        {
            return uint128((this.data[0] >> (shift - 64)));
        }
        return uint128();
    }

    @nogc nothrow pure @safe unittest
    {
        assert((uint128(ulong.max, ulong.max) >> 128) == uint128());
        assert((uint128(1, 2) >> 64) == uint128(1));
        assert((uint128(1, 2) >> 0) == uint128(1, 2));
        assert((uint128(1, 0) >> 1) == uint128(0x8000000000000000));
        assert((uint128(2, 0) >> 65) == uint128(1));
    }

    uint128 opBinary(string op : "<<")(ulong shift) const
    {
        if (shift == 0)
        {
            return this;
        }
        else if (shift < 64)
        {
            const ulong upper = (this.data[0] << shift)
                              + (this.data[1] >> (64 - shift));
            return uint128(upper, this.data[1] << shift);
        }
        else if (shift < 128)
        {
            return uint128(this.data[1] << (shift - 64), 0);
        }
        return uint128();
    }

    bool opEquals(uint128 that) const @nogc nothrow pure @safe
    {
        return equal(this.data[], that.data[]);
    }

    int opCmp(uint128 that) const @nogc nothrow pure @safe
    {
        if (this.data[0] > that.data[0]
         || (this.data[0] == that.data[0] && this.data[1] > that.data[1]))
        {
            return 1;
        }
        else if (this.data[0] == that.data[0] && this.data[1] == that.data[1])
        {
            return 0;
        }
        return -1;
    }

    bool opEquals(ulong that) const @nogc nothrow pure @safe
    {
        return this.data[0] == 0 && this.data[1] == that;
    }

    int opCmp(ulong that) const @nogc nothrow pure @safe
    {
        if (this.data[0] != 0 || (this.data[0] == 0 && this.data[1] > that))
        {
            return 1;
        }
        return (this.data[1] == that) ? 0 : -1;
    }

    @nogc nothrow pure @safe unittest
    {
        assert(uint128(1, 2) >= uint128(1, 2));
        assert(uint128(1, ulong.max) < uint128(2, 0));
        assert(uint128(40) < uint128(50));
    }

    @nogc nothrow pure @safe unittest
    {
        assert(uint128(1, 0) != uint128(1));
        assert(uint128(1, 2) == uint128(1, 2));
    }

    @nogc nothrow pure @safe unittest
    {
        assert(uint128(1, 2) <= uint128(1, 2));
    }

    @nogc nothrow pure @safe unittest
    {
        assert(uint128(1, 2) <= uint128(1, 2));
        assert(uint128(2, 0) > uint128(1, ulong.max));
        assert(uint128(50) > uint128(40));
    }

    @nogc nothrow pure @safe unittest
    {
        assert(uint128(1, 2) >= uint128(1, 2));
    }

    private @property ubyte bits() const @nogc nothrow pure @safe
    {
        ubyte count;
        if (this.data[0] > 0)
        {
            count = 64;
            for (ulong digit = this.data[0]; digit > 0; digit >>= 1)
            {
                ++count;
            }
        }
        else
        {
            for (ulong digit = this.data[1]; digit > 0; digit >>= 1)
            {
                ++count;
            }
        }
        return count;
    }

    @nogc nothrow pure @safe unittest
    {
        assert(uint128().bits == 0);
        assert(uint128(1, 0).bits == 65);
    }

    T opCast(T : bool)()
    {
        return this.data[0] != 0 || this.data[1] != 0;
    }

    T opCast(T : ulong)()
    {
        return this.data[1];
    }

    Tuple!(uint128, uint128) divMod(ulong rhs) const @nogc nothrow pure @safe
    in (rhs != uint128(), "Division by 0")
    {
        if (rhs == 1)
        {
            return typeof(return)(this, uint128());
        }
        else if (this == rhs)
        {
            return typeof(return)(uint128(1), uint128());
        }
        else if (this == uint128() || this < rhs)
        {
            return typeof(return)(uint128(), this);
        }

        typeof(return) result;
        for (ubyte x = this.bits; x > 0; --x)
        {
            result[0]  = result[0] << 1;
            result[1] = result[1] << 1;

            if ((this >> (x - 1U)) & 1)
            {
                ++result[1];
            }

            if (result[1] >= rhs)
            {
                if (result[1].data[1] < rhs)
                {
                    --result[1].data[0];
                }
                result[1].data[1] -= rhs;
                ++result[0];
            }
        }
        return result;
    }

    uint128 opBinary(string op : "/")(ulong rhs)
    {
        return divMod(rhs)[0];
    }

    uint128 opBinary(string op : "%")(ulong rhs) const
    {
        return divMod(rhs)[1];
    }
}

private double next(const double value) @nogc nothrow pure @safe
{
    FloatBits!double bits = { floating: value };
    ++bits.integral;
    return bits.floating;
}

private double previous(const double value) @nogc nothrow pure @safe
{
    FloatBits!double bits = { floating: value };
    --bits.integral;
    return bits.floating;
}

private uint128 raise2ToExp(double value) @nogc nothrow pure @safe
{
    FloatBits!double bits = { floating: value };

    return uint128(1) << ((bits.integral >> 52) - 1023);
}

private int indexMismatch(ulong low, ulong high) @nogc nothrow pure @safe
{
    enum ulong power10 = 10000000000UL;
    const ulong a = low / power10;
    const ulong b = high / power10;
    int index;

    if (a != b)
    {
        index = 10;
        low = a;
        high = b;
    }

    for (;; ++index)
    {
        low /= 10;
        high /= 10;

        if (low == high)
        {
            return index;
        }
    }
}

private char[] errol2(double value,
                      return ref char[512] buffer,
                      out int exponent) @nogc nothrow pure @safe
in (value > 9.007199254740992e15 && value < 3.40282366920938e38)
{
    auto v = uint128(value);
    auto leftBoundary = v + raise2ToExp((value - previous(value)) / 2.0);
    auto rightBoundary = v - raise2ToExp((next(value) - value) / 2.0);
    FloatBits!double bits = { floating: value };

    if (bits.integral & 0x1)
    {
        --leftBoundary;
    }
    else
    {
        --rightBoundary;
    }

    enum ulong power19 = cast(ulong) 1e19;

    auto qr = leftBoundary.divMod(power19);
    auto low = cast(ulong) qr[1];
    const lowFactor = cast(ulong) (qr[0] % power19);

    qr = rightBoundary.divMod(power19);
    auto high = cast(ulong) qr[1];
    const highFactor = cast(ulong) (qr[0] % power19);
    size_t digitIndex;

    if (lowFactor != highFactor)
    {
        low = lowFactor;
        high = highFactor;
        v = v / cast(ulong) 1e18;
    }
    else
    {
        digitIndex = 1;
    }

    int mismatch = indexMismatch(low, high);
    ulong tens = 1;
    for (; digitIndex < mismatch; ++digitIndex)
    {
        tens *= 10;
    }
    const midpoint = cast(ulong) (v / tens);

    if (lowFactor != highFactor)
    {
        mismatch += 19;
    }

    char[21] intBuffer;
    auto intSlice = integral2String(midpoint, intBuffer);

    if (mismatch != 0)
    {
        if (intSlice[$ - 1] >= '5')
        {
            ++intSlice[$ - 2];
        }
        intSlice.popBack();
    }
    const begin = buffer.length - intSlice.length;
    tanya.memory.op.copy(intSlice, buffer[begin .. $]);

    exponent = cast(int) (intSlice.length + mismatch);

    return buffer[begin .. $];
}

@nogc nothrow pure @safe unittest
{
    char[512] buf;
    int e;

    assert(errol2(9.007199254740994e15, buf, e) == "9007199254740994");
    assert(e == 16);

    assert(errol2(9.007199254740994e25, buf, e) == "9007199254740994");
    assert(e == 26);
}

private char[] errolFixed(double value,
                          return ref char[512] buffer,
                          out int exponent) @nogc nothrow pure @safe
in (value >= 16.0 && value <= 9.007199254740992e15)
{
    auto decimal = cast(ulong) value;
    auto n = cast(double) decimal;

    double midpoint = value - n;
    double leftBoundary = (previous(value) - n + midpoint) / 2.0;
    double rightBoundary = (next(value) - n + midpoint) / 2.0;

    char[21] intBuffer;
    auto intSlice = integral2String(decimal, intBuffer);
    tanya.memory.op.copy(intSlice, buffer);
    exponent = cast(int) intSlice.length;

    size_t position = exponent;
    if (midpoint != 0.0)
    {
        while (midpoint != 0.0)
        {
            leftBoundary *= 10.0;
            const leftDigit = cast(ubyte) leftBoundary;
            leftBoundary -= leftDigit;

            midpoint *= 10.0;
            const middleDigit = cast(ubyte) midpoint;
            midpoint -= middleDigit;

            rightBoundary *= 10.0;
            const rightDigit = cast(ubyte) rightBoundary;
            rightBoundary -= rightDigit;

            buffer[position++] = cast(char) (middleDigit + '0');

            if (rightDigit != leftDigit || position > 50)
            {
                break;
            }
        }

        if (midpoint > 0.5
         || ((midpoint == 0.5) && (buffer[position - 1] & 0x1)))
        {
            ++buffer[position - 1];
        }
    }
    else
    {
        for (; buffer[position - 1] == '0'; --position)
        {
            buffer[position - 1] = '\0';
        }
    }

    return buffer[0 .. position];
}

@nogc nothrow pure @safe unittest
{
    char[512] num;
    int exponent;
    {
        assert(errolFixed(16.0, num, exponent) == "16");
        assert(exponent == 2);
    }
    {
        assert(errolFixed(38234.1234, num, exponent) == "382341234");
        assert(exponent == 5);
    }
}

private char[] errol3(double value,
                      return ref char[512] buffer,
                      out int exponent) @nogc nothrow pure @safe
{
    static struct Pathology
    {
        ulong representation;
        string digits;
        int exponent;
    }

    static immutable Pathology[432] pathologies = [
        { 0x001d243f646eaf51, "40526371999771488", -307 },
        { 0x002d243f646eaf51, "81052743999542975", -307 },
        { 0x00ab7aa3d73f6658, "1956574196882425", -304 },
        { 0x00bb7aa3d73f6658, "391314839376485", -304 },
        { 0x00cb7aa3d73f6658, "78262967875297", -304 },
        { 0x00f5d15b26b80e30, "4971131903427841", -303 },
        { 0x010b7aa3d73f6658, "1252207486004752", -302 },
        { 0x011b7aa3d73f6658, "2504414972009504", -302 },
        { 0x012b7aa3d73f6658, "5008829944019008", -302 },
        { 0x0180a0f3c55062c5, "19398723835545928", -300 },
        { 0x0180a0f3c55062c6, "1939872383554593", -300 },
        { 0x0190a0f3c55062c5, "38797447671091856", -300 },
        { 0x0190a0f3c55062c6, "3879744767109186", -300 },
        { 0x01f393b456eef178, "29232758945460627", -298 },
        { 0x03719f08ccdccfe5, "44144884605471774", -291 },
        { 0x037be9d5a60850b5, "69928982131052126", -291 },
        { 0x03dc25ba6a45de02, "45129663866844427", -289 },
        { 0x05798e3445512a6e, "27497183057384368", -281 },
        { 0x05798e3445512a6f, "2749718305738437", -281 },
        { 0x05898e3445512a6e, "54994366114768736", -281 },
        { 0x05898e3445512a6f, "5499436611476874", -281 },
        { 0x06afdadafcacdf85, "17970091719480621", -275 },
        { 0x06bfdadafcacdf85, "35940183438961242", -275 },
        { 0x06ceb7f2c53db97f, "69316187906522606", -275 },
        { 0x06cfdadafcacdf85, "71880366877922484", -275 },
        { 0x06e8b03fd6894b66, "22283747288943228", -274 },
        { 0x06f8b03fd6894b66, "44567494577886457", -274 },
        { 0x07bfe89cf1bd76ac, "23593494977819109", -270 },
        { 0x07c1707c02068785, "25789638850173173", -270 },
        { 0x07cfe89cf1bd76ac, "47186989955638217", -270 },
        { 0x08567a3c8dc4bc9c, "17018905290641991", -267 },
        { 0x08667a3c8dc4bc9c, "34037810581283983", -267 },
        { 0x089c25584881552a, "3409719593752201", -266 },
        { 0x08ac25584881552a, "6819439187504402", -266 },
        { 0x08dfa7ebe304ee3d, "6135911659254281", -265 },
        { 0x08dfa7ebe304ee3e, "61359116592542813", -265 },
        { 0x096822507db6a8fd, "23951010625355228", -262 },
        { 0x097822507db6a8fd, "47902021250710456", -262 },
        { 0x09e41934d77659be, "51061856989121905", -260 },
        { 0x0b8f3d82e9356287, "53263359599109627", -252 },
        { 0x0c27b35936d56e27, "4137829457097561", -249 },
        { 0x0c27b35936d56e28, "41378294570975613", -249 },
        { 0x0c43165633977bc9, "13329597309520689", -248 },
        { 0x0c43165633977bca, "1332959730952069", -248 },
        { 0x0c53165633977bc9, "26659194619041378", -248 },
        { 0x0c53165633977bca, "2665919461904138", -248 },
        { 0x0c63165633977bc9, "53318389238082755", -248 },
        { 0x0c63165633977bca, "5331838923808276", -248 },
        { 0x0c7e9eddbbb259b4, "1710711888535566", -247 },
        { 0x0c8e9eddbbb259b4, "3421423777071132", -247 },
        { 0x0c9e9eddbbb259b4, "6842847554142264", -247 },
        { 0x0e104273b18918b0, "6096109271490509", -240 },
        { 0x0e104273b18918b1, "609610927149051", -240 },
        { 0x0e204273b18918b0, "12192218542981019", -239 },
        { 0x0e204273b18918b1, "1219221854298102", -239 },
        { 0x0e304273b18918b0, "24384437085962037", -239 },
        { 0x0e304273b18918b1, "2438443708596204", -239 },
        { 0x0f1d16d6d4b89689, "7147520638007367", -235 },
        { 0x0fd6ba8608faa6a8, "2287474118824999", -231 },
        { 0x0fd6ba8608faa6a9, "22874741188249992", -231 },
        { 0x0fe6ba8608faa6a8, "4574948237649998", -231 },
        { 0x0fe6ba8608faa6a9, "45749482376499984", -231 },
        { 0x1006b100e18e5c17, "18269851255456139", -230 },
        { 0x1016b100e18e5c17, "36539702510912277", -230 },
        { 0x104f48347c60a1be, "40298468695006992", -229 },
        { 0x105f48347c60a1be, "80596937390013985", -229 },
        { 0x10a4139a6b17b224, "16552474403007851", -227 },
        { 0x10b4139a6b17b224, "33104948806015703", -227 },
        { 0x12cb91d317c8ebe9, "39050270537318193", -217 },
        { 0x13627383c5456c5e, "26761990828289327", -214 },
        { 0x138fb24e492936f6, "1838927069906671", -213 },
        { 0x139fb24e492936f6, "3677854139813342", -213 },
        { 0x13afb24e492936f6, "7355708279626684", -213 },
        { 0x13f93bb1e72a2033, "18738512510673039", -211 },
        { 0x14093bb1e72a2033, "37477025021346077", -211 },
        { 0x1466cc4fc92a0fa6, "21670630627577332", -209 },
        { 0x1476cc4fc92a0fa6, "43341261255154663", -209 },
        { 0x148048cb468bc208, "619160875073638", -209 },
        { 0x149048cb468bc209, "12383217501472761", -208 },
        { 0x14a048cb468bc209, "24766435002945523", -208 },
        { 0x1504c0b3a63c1444, "2019986500244655", -206 },
        { 0x1514c0b3a63c1444, "403997300048931", -206 },
        { 0x161ba6008389068a, "35273912934356928", -201 },
        { 0x162ba6008389068a, "70547825868713855", -201 },
        { 0x168cfab1a09b49c4, "47323883490786093", -199 },
        { 0x175090684f5fe997, "22159015457577768", -195 },
        { 0x175090684f5fe998, "2215901545757777", -195 },
        { 0x176090684f5fe997, "44318030915155535", -195 },
        { 0x176090684f5fe998, "4431803091515554", -195 },
        { 0x17e4116d591ef1fb, "13745435592982211", -192 },
        { 0x17f4116d591ef1fb, "27490871185964422", -192 },
        { 0x1804116d591ef1fb, "54981742371928845", -192 },
        { 0x18a710b7a2ef18b7, "64710073234908765", -189 },
        { 0x18cde996371c6060, "33567940583589088", -188 },
        { 0x18d99fccca44882a, "57511323531737074", -188 },
        { 0x18dde996371c6060, "67135881167178176", -188 },
        { 0x199a2cf604c30d3f, "2406355597625261", -184 },
        { 0x19aa2cf604c30d3f, "4812711195250522", -184 },
        { 0x1b5ebddc6593c857, "75862936714499446", -176 },
        { 0x1c513770474911bd, "27843818440071113", -171 },
        { 0x1d1b1ad9101b1bfd, "1795518315109779", -167 },
        { 0x1d2b1ad9101b1bfd, "3591036630219558", -167 },
        { 0x1d3b1ad9101b1bfd, "7182073260439116", -167 },
        { 0x1e3035e7b5183922, "28150140033551147", -162 },
        { 0x1e4035e7b5183923, "563002800671023", -162 },
        { 0x1e5035e7b5183923, "1126005601342046", -161 },
        { 0x1e6035e7b5183923, "2252011202684092", -161 },
        { 0x1e7035e7b5183923, "4504022405368184", -161 },
        { 0x1fd5a79c4e71d028, "2523567903248961", -154 },
        { 0x1fe5a79c4e71d028, "5047135806497922", -154 },
        { 0x20cc29bc6879dfcd, "10754533488024391", -149 },
        { 0x20dc29bc6879dfcd, "21509066976048781", -149 },
        { 0x20e8823a57adbef8, "37436263604934127", -149 },
        { 0x20ec29bc6879dfcd, "43018133952097563", -149 },
        { 0x2104dab846e19e25, "1274175730310828", -148 },
        { 0x2114dab846e19e25, "2548351460621656", -148 },
        { 0x2124dab846e19e25, "5096702921243312", -148 },
        { 0x218ce77c2b3328fb, "45209911804158747", -146 },
        { 0x220ce77c2b3328fb, "11573737421864639", -143 },
        { 0x220ce77c2b3328fc, "1157373742186464", -143 },
        { 0x221ce77c2b3328fb, "23147474843729279", -143 },
        { 0x221ce77c2b3328fc, "2314747484372928", -143 },
        { 0x222ce77c2b3328fb, "46294949687458557", -143 },
        { 0x222ce77c2b3328fc, "4629494968745856", -143 },
        { 0x229197b290631476, "36067106647774144", -141 },
        { 0x233f346f9ed36b89, "65509428048152994", -138 },
        { 0x240a28877a09a4e0, "44986453555921307", -134 },
        { 0x240a28877a09a4e1, "4498645355592131", -134 },
        { 0x243441ed79830181, "27870735485790148", -133 },
        { 0x243441ed79830182, "2787073548579015", -133 },
        { 0x244441ed79830181, "55741470971580295", -133 },
        { 0x244441ed79830182, "557414709715803", -133 },
        { 0x245441ed79830181, "11148294194316059", -132 },
        { 0x245441ed79830182, "1114829419431606", -132 },
        { 0x246441ed79830181, "22296588388632118", -132 },
        { 0x246441ed79830182, "2229658838863212", -132 },
        { 0x247441ed79830181, "44593176777264236", -132 },
        { 0x247441ed79830182, "4459317677726424", -132 },
        { 0x248b23b50fc204db, "11948502190822011", -131 },
        { 0x249b23b50fc204db, "23897004381644022", -131 },
        { 0x24ab23b50fc204db, "47794008763288043", -131 },
        { 0x2541e4ee41180c0a, "32269008655522087", -128 },
        { 0x2633dc6227de9148, "1173600085235347", -123 },
        { 0x2643dc6227de9148, "2347200170470694", -123 },
        { 0x2653dc6227de9148, "4694400340941388", -123 },
        { 0x277aacfcb88c92d6, "16528675364037979", -117 },
        { 0x277aacfcb88c92d7, "1652867536403798", -117 },
        { 0x278aacfcb88c92d6, "33057350728075958", -117 },
        { 0x278aacfcb88c92d7, "3305735072807596", -117 },
        { 0x279aacfcb88c92d6, "66114701456151916", -117 },
        { 0x279aacfcb88c92d7, "6611470145615192", -117 },
        { 0x279b5cd8bbdd8770, "67817280930489786", -117 },
        { 0x27bbb4c6bd8601bd, "27467428267063488", -116 },
        { 0x27cbb4c6bd8601bd, "54934856534126976", -116 },
        { 0x289d52af46e5fa69, "4762882274418243", -112 },
        { 0x289d52af46e5fa6a, "47628822744182433", -112 },
        { 0x28b04a616046e074, "10584182832040541", -111 },
        { 0x28c04a616046e074, "21168365664081082", -111 },
        { 0x28d04a616046e074, "42336731328162165", -111 },
        { 0x297c2c31a31998ae, "74973710847373845", -108 },
        { 0x2a3eeff57768f88c, "33722866731879692", -104 },
        { 0x2a4eeff57768f88c, "67445733463759384", -104 },
        { 0x2b8e3a0aeed7be19, "69097540994131414", -98 },
        { 0x2bdec922478c0421, "22520091703825729", -96 },
        { 0x2beec922478c0421, "45040183407651457", -96 },
        { 0x2c2379f099a86227, "45590931008842566", -95 },
        { 0x2cc7c3fba45c1271, "5696647848853893", -92 },
        { 0x2cc7c3fba45c1272, "56966478488538934", -92 },
        { 0x2cf4f14348a4c5db, "40159515855058247", -91 },
        { 0x2d04f14348a4c5db, "8031903171011649", -91 },
        { 0x2d44f14348a4c5db, "12851045073618639", -89 },
        { 0x2d44f14348a4c5dc, "1285104507361864", -89 },
        { 0x2d54f14348a4c5db, "25702090147237278", -89 },
        { 0x2d54f14348a4c5dc, "2570209014723728", -89 },
        { 0x2d5a8c931c19b77a, "3258302752792233", -89 },
        { 0x2d64f14348a4c5db, "51404180294474556", -89 },
        { 0x2d64f14348a4c5dc, "5140418029447456", -89 },
        { 0x2d6a8c931c19b77a, "6516605505584466", -89 },
        { 0x2efc1249e96b6d8d, "23119896893873391", -81 },
        { 0x2f0c1249e96b6d8d, "46239793787746783", -81 },
        { 0x2f0f6b23cfe98807, "51753157237874753", -81 },
        { 0x2fa387cf9cb4ad4e, "32943123175907307", -78 },
        { 0x2fe91b9de4d5cf31, "67761208324172855", -77 },
        { 0x3081eab25ad0fcf7, "49514357246452655", -74 },
        { 0x308ddc7e975c5045, "8252392874408775", -74 },
        { 0x308ddc7e975c5046, "82523928744087755", -74 },
        { 0x309ddc7e975c5045, "1650478574881755", -73 },
        { 0x30addc7e975c5045, "330095714976351", -73 },
        { 0x30bddc7e975c5045, "660191429952702", -73 },
        { 0x3149190e30e46c1d, "28409785190323268", -70 },
        { 0x3150ed9bd6bfd003, "3832399419240467", -70 },
        { 0x3159190e30e46c1d, "56819570380646536", -70 },
        { 0x317d2ec75df6ba2a, "26426943389906988", -69 },
        { 0x318d2ec75df6ba2a, "52853886779813977", -69 },
        { 0x321aedaa0fc32ac8, "2497072464210591", -66 },
        { 0x322aedaa0fc32ac8, "4994144928421182", -66 },
        { 0x32448050091c3c24, "15208651188557789", -65 },
        { 0x32548050091c3c24, "30417302377115577", -65 },
        { 0x328f5a18504dfaac, "37213051060716888", -64 },
        { 0x329f5a18504dfaac, "74426102121433776", -64 },
        { 0x3336dca59d035820, "55574205388093594", -61 },
        { 0x33beef5e1f90ac34, "1925091640472375", -58 },
        { 0x33ceef5e1f90ac34, "385018328094475", -58 },
        { 0x33deef5e1f90ac34, "77003665618895", -58 },
        { 0x33eeef5e1f90ac35, "15400733123779001", -57 },
        { 0x33feef5e1f90ac35, "30801466247558002", -57 },
        { 0x340eef5e1f90ac35, "61602932495116004", -57 },
        { 0x341eef5e1f90ac35, "12320586499023201", -56 },
        { 0x34228f9edfbd3420, "14784703798827841", -56 },
        { 0x342eef5e1f90ac35, "24641172998046401", -56 },
        { 0x34328f9edfbd3420, "29569407597655683", -56 },
        { 0x343eef5e1f90ac35, "49282345996092803", -56 },
        { 0x344eef5e1f90ac35, "9856469199218561", -56 },
        { 0x345eef5e1f90ac35, "19712938398437121", -55 },
        { 0x346eef5e1f90ac35, "39425876796874242", -55 },
        { 0x347eef5e1f90ac35, "78851753593748485", -55 },
        { 0x35008621c4199208, "21564764513659432", -52 },
        { 0x35108621c4199208, "43129529027318865", -52 },
        { 0x35e0ac2e7f90b8a3, "35649516398744314", -48 },
        { 0x35ef1de1f7f14439, "66534156679273626", -48 },
        { 0x361dde4a4ab13e09, "51091836539008967", -47 },
        { 0x366b870de5d93270, "15068094409836911", -45 },
        { 0x367b870de5d93270, "30136188819673822", -45 },
        { 0x368b870de5d93270, "60272377639347644", -45 },
        { 0x375b20c2f4f8d49f, "4865841847892019", -41 },
        { 0x375b20c2f4f8d4a0, "48658418478920193", -41 },
        { 0x37f25d342b1e33e5, "33729482964455627", -38 },
        { 0x3854faba79ea92ec, "24661175471861008", -36 },
        { 0x3854faba79ea92ed, "2466117547186101", -36 },
        { 0x3864faba79ea92ec, "49322350943722016", -36 },
        { 0x3864faba79ea92ed, "4932235094372202", -36 },
        { 0x3a978cfcab31064c, "19024128529074359", -25 },
        { 0x3a978cfcab31064d, "1902412852907436", -25 },
        { 0x3aa78cfcab31064c, "38048257058148717", -25 },
        { 0x3aa78cfcab31064d, "3804825705814872", -25 },
        { 0x47f52d02c7e14af7, "45035996273704964", 39 },
        { 0x490cd230a7ff47c3, "80341375308088225", 44 },
        { 0x4919d9577de925d5, "14411294198511291", 45 },
        { 0x4929d9577de925d5, "28822588397022582", 45 },
        { 0x4931159a8bd8a240, "38099461575161174", 45 },
        { 0x4939d9577de925d5, "57645176794045164", 45 },
        { 0x49ccadd6dd730c96, "32745697577386472", 48 },
        { 0x49dcadd6dd730c96, "65491395154772944", 48 },
        { 0x4a6bb6979ae39c49, "32402369146794532", 51 },
        { 0x4a7bb6979ae39c49, "64804738293589064", 51 },
        { 0x4b9a32ac316fb3ab, "16059290466419889", 57 },
        { 0x4b9a32ac316fb3ac, "1605929046641989", 57 },
        { 0x4baa32ac316fb3ab, "32118580932839778", 57 },
        { 0x4baa32ac316fb3ac, "3211858093283978", 57 },
        { 0x4bba32ac316fb3ab, "64237161865679556", 57 },
        { 0x4bba32ac316fb3ac, "6423716186567956", 57 },
        { 0x4c85564fb098c955, "42859354584576066", 61 },
        { 0x4cef20b1a0d7f626, "4001624164855121", 63 },
        { 0x4cff20b1a0d7f626, "8003248329710242", 63 },
        { 0x4e2e2785c3a2a20a, "4064803033949531", 69 },
        { 0x4e2e2785c3a2a20b, "40648030339495312", 69 },
        { 0x4e3e2785c3a2a20a, "8129606067899062", 69 },
        { 0x4e3e2785c3a2a20b, "81296060678990625", 69 },
        { 0x4e6454b1aef62c8d, "4384946084578497", 70 },
        { 0x4e80fde34c996086, "1465909318208761", 71 },
        { 0x4e90fde34c996086, "2931818636417522", 71 },
        { 0x4ea9a2c2a34ac2f9, "8846583389443709", 71 },
        { 0x4ea9a2c2a34ac2fa, "884658338944371", 71 },
        { 0x4eb9a2c2a34ac2f9, "17693166778887419", 72 },
        { 0x4eb9a2c2a34ac2fa, "1769316677888742", 72 },
        { 0x4ec9a2c2a34ac2f9, "35386333557774838", 72 },
        { 0x4ec9a2c2a34ac2fa, "3538633355777484", 72 },
        { 0x4ed9a2c2a34ac2f9, "70772667115549675", 72 },
        { 0x4ed9a2c2a34ac2fa, "7077266711554968", 72 },
        { 0x4f28750ea732fdae, "21606114462319112", 74 },
        { 0x4f38750ea732fdae, "43212228924638223", 74 },
        { 0x503ca9bade45b94a, "3318949537676913", 79 },
        { 0x504ca9bade45b94a, "6637899075353826", 79 },
        { 0x513843e10734fa57, "18413733104063271", 84 },
        { 0x514843e10734fa57, "36827466208126543", 84 },
        { 0x51a3274280201a89, "18604316837693468", 86 },
        { 0x51b3274280201a89, "37208633675386937", 86 },
        { 0x51e71760b3c0bc13, "35887030159858487", 87 },
        { 0x521f6a5025e71a61, "39058878597126768", 88 },
        { 0x522f6a5025e71a61, "78117757194253536", 88 },
        { 0x52c6a47d4e7ec633, "57654578150150385", 91 },
        { 0x55693ba3249a8511, "2825769263311679", 104 },
        { 0x55793ba3249a8511, "5651538526623358", 104 },
        { 0x574fe0403124a00e, "38329392744333992", 113 },
        { 0x575fe0403124a00e, "76658785488667984", 113 },
        { 0x57763ae2caed4528, "2138446062528161", 114 },
        { 0x57863ae2caed4528, "4276892125056322", 114 },
        { 0x57d561def4a9ee32, "1316415380484425", 116 },
        { 0x57e561def4a9ee32, "263283076096885", 116 },
        { 0x57f561def4a9ee32, "52656615219377", 116 },
        { 0x580561def4a9ee31, "10531323043875399", 117 },
        { 0x581561def4a9ee31, "21062646087750798", 117 },
        { 0x582561def4a9ee31, "42125292175501597", 117 },
        { 0x584561def4a9ee31, "16850116870200639", 118 },
        { 0x585561def4a9ee31, "33700233740401277", 118 },
        { 0x5935ede8cce30845, "56627018760181905", 122 },
        { 0x59d0dd8f2788d699, "44596066840334405", 125 },
        { 0x5b45ed1f039cebfe, "48635409059147446", 132 },
        { 0x5b55ed1f039cebfe, "9727081811829489", 132 },
        { 0x5b55ed1f039cebff, "972708181182949", 132 },
        { 0x5beaf5b5378aa2e5, "61235700073843246", 135 },
        { 0x5bfaf5b5378aa2e5, "12247140014768649", 136 },
        { 0x5c0af5b5378aa2e5, "24494280029537298", 136 },
        { 0x5c1af5b5378aa2e5, "48988560059074597", 136 },
        { 0x5c4ef3052ef0a361, "4499029632233837", 137 },
        { 0x5c6cf45d333da323, "16836228873919609", 138 },
        { 0x5e1780695036a679, "18341526859645389", 146 },
        { 0x5e2780695036a679, "36683053719290777", 146 },
        { 0x5e54ec8fd70420c7, "2612787385440923", 147 },
        { 0x5e64ec8fd70420c7, "5225574770881846", 147 },
        { 0x5e6b5e2f86026f05, "6834859331393543", 147 },
        { 0x5f9aeac2d1ea2695, "35243988108650928", 153 },
        { 0x5faaeac2d1ea2695, "70487976217301855", 153 },
        { 0x6009813653f62db7, "42745323906998127", 155 },
        { 0x611260322d04d50b, "40366692112133834", 160 },
        { 0x624be064a3fb2725, "32106017483029628", 166 },
        { 0x625be064a3fb2725, "64212034966059256", 166 },
        { 0x64112a13daa46fe4, "10613173493886741", 175 },
        { 0x64212a13daa46fe4, "21226346987773482", 175 },
        { 0x64312a13daa46fe4, "42452693975546964", 175 },
        { 0x671dcfee6690ffc6, "51886190678901447", 189 },
        { 0x672dcfee6690ffc6, "10377238135780289", 190 },
        { 0x673dcfee6690ffc6, "20754476271560579", 190 },
        { 0x674dcfee6690ffc6, "41508952543121158", 190 },
        { 0x675dcfee6690ffc6, "83017905086242315", 190 },
        { 0x677a77581053543b, "29480080280199528", 191 },
        { 0x678a77581053543b, "58960160560399056", 191 },
        { 0x6820ee7811241ad3, "38624526316654214", 194 },
        { 0x682d3683fa3d1ee0, "66641177824100826", 194 },
        { 0x699873e3758bc6b3, "4679330956996797", 201 },
        { 0x699cb490951e8515, "5493127645170153", 201 },
        { 0x6a6cc08102f0da5b, "45072812455233127", 205 },
        { 0x6b3ef9beaa7aa583, "39779219869333628", 209 },
        { 0x6b3ef9beaa7aa584, "3977921986933363", 209 },
        { 0x6b4ef9beaa7aa583, "79558439738667255", 209 },
        { 0x6b4ef9beaa7aa584, "7955843973866726", 209 },
        { 0x6b7896beb0c66eb9, "50523702331566894", 210 },
        { 0x6b7b86d8c3df7cd1, "56560320317673966", 210 },
        { 0x6bdf20938e7414bb, "40933393326155808", 212 },
        { 0x6be6c9e14b7c22c4, "59935550661561155", 212 },
        { 0x6bef20938e7414bb, "81866786652311615", 212 },
        { 0x6bf6c9e14b7c22c3, "1198711013231223", 213 },
        { 0x6bf6c9e14b7c22c4, "11987110132312231", 213 },
        { 0x6c06c9e14b7c22c3, "2397422026462446", 213 },
        { 0x6c06c9e14b7c22c4, "23974220264624462", 213 },
        { 0x6c16c9e14b7c22c3, "4794844052924892", 213 },
        { 0x6c16c9e14b7c22c4, "47948440529248924", 213 },
        { 0x6ce75d226331d03a, "40270821632825953", 217 },
        { 0x6cf75d226331d03a, "8054164326565191", 217 },
        { 0x6d075d226331d03a, "16108328653130381", 218 },
        { 0x6d175d226331d03a, "32216657306260762", 218 },
        { 0x6d275d226331d03a, "64433314612521525", 218 },
        { 0x6d4b9445072f4374, "30423431424080128", 219 },
        { 0x6d5a3bdac4f00f33, "57878622568856074", 219 },
        { 0x6d5b9445072f4374, "60846862848160256", 219 },
        { 0x6e4a2fbffdb7580c, "18931483477278361", 224 },
        { 0x6e5a2fbffdb7580c, "37862966954556723", 224 },
        { 0x6e927edd0dbb8c08, "4278822588984689", 225 },
        { 0x6e927edd0dbb8c09, "42788225889846894", 225 },
        { 0x6ee1c382c3819a0a, "1315044757954692", 227 },
        { 0x6ef1c382c3819a0a, "2630089515909384", 227 },
        { 0x70f60cf8f38b0465, "14022275014833741", 237 },
        { 0x71060cf8f38b0465, "28044550029667482", 237 },
        { 0x7114390c68b888ce, "5143975308105889", 237 },
        { 0x71160cf8f38b0465, "56089100059334965", 237 },
        { 0x714fb4840532a9e5, "64517311884236306", 238 },
        { 0x71b1d7cb7eae05d9, "46475406389115295", 240 },
        { 0x727fca36c06cf106, "3391607972972965", 244 },
        { 0x728fca36c06cf106, "678321594594593", 244 },
        { 0x72eba10d818fdafd, "3773057430100257", 246 },
        { 0x72fba10d818fdafd, "7546114860200514", 246 },
        { 0x737a37935f3b71c9, "1833078106007497", 249 },
        { 0x738a37935f3b71c9, "3666156212014994", 249 },
        { 0x73972852443155ae, "64766168833734675", 249 },
        { 0x739a37935f3b71c9, "7332312424029988", 249 },
        { 0x754fe46e378bf132, "1197160149212491", 258 },
        { 0x754fe46e378bf133, "11971601492124911", 258 },
        { 0x755fe46e378bf132, "2394320298424982", 258 },
        { 0x755fe46e378bf133, "23943202984249821", 258 },
        { 0x756fe46e378bf132, "4788640596849964", 258 },
        { 0x756fe46e378bf133, "47886405968499643", 258 },
        { 0x76603d7cb98edc58, "1598075144577112", 263 },
        { 0x76603d7cb98edc59, "15980751445771122", 263 },
        { 0x76703d7cb98edc58, "3196150289154224", 263 },
        { 0x76703d7cb98edc59, "31961502891542243", 263 },
        { 0x782f7c6a9ad432a1, "83169412421960475", 271 },
        { 0x78447e17e7814ce7, "21652206566352648", 272 },
        { 0x78547e17e7814ce7, "43304413132705296", 272 },
        { 0x7856d2aa2fc5f2b5, "48228872759189434", 272 },
        { 0x7964066d88c7cab8, "5546524276967009", 277 },
        { 0x799d696737fe68c7, "65171333649148234", 278 },
        { 0x7ace779fddf21621, "3539481653469909", 284 },
        { 0x7ace779fddf21622, "35394816534699092", 284 },
        { 0x7ade779fddf21621, "7078963306939818", 284 },
        { 0x7ade779fddf21622, "70789633069398184", 284 },
        { 0x7bc3b063946e10ae, "14990287287869931", 289 },
        { 0x7bd3b063946e10ae, "29980574575739863", 289 },
        { 0x7c0c283ffc61c87d, "34300126555012788", 290 },
        { 0x7c1c283ffc61c87d, "68600253110025576", 290 },
        { 0x7c31926c7a7122ba, "17124434349589332", 291 },
        { 0x7c41926c7a7122ba, "34248868699178663", 291 },
        { 0x7d0a85c6f7fba05d, "2117392354885733", 295 },
        { 0x7d1a85c6f7fba05d, "4234784709771466", 295 },
        { 0x7d52a5daf9226f04, "47639264836707725", 296 },
        { 0x7d8220e1772428d7, "37049827284413546", 297 },
        { 0x7d9220e1772428d7, "7409965456882709", 297 },
        { 0x7da220e1772428d7, "14819930913765419", 298 },
        { 0x7db220e1772428d7, "29639861827530837", 298 },
        { 0x7df22815078cb97b, "47497368114750945", 299 },
        { 0x7dfe5aceedf1c1f1, "79407577493590275", 299 },
        { 0x7e022815078cb97b, "9499473622950189", 299 },
        { 0x7e122815078cb97b, "18998947245900378", 300 },
        { 0x7e222815078cb97b, "37997894491800756", 300 },
        { 0x7e8a9b45a91f1700, "35636409637317792", 302 },
        { 0x7e9a9b45a91f1700, "71272819274635585", 302 },
        { 0x7eb6202598194bee, "23707742595255608", 303 },
        { 0x7ec490abad057752, "4407140524515149", 303 },
        { 0x7ec6202598194bee, "47415485190511216", 303 },
        { 0x7ee3c8eeb77b8d05, "16959746108988652", 304 },
        { 0x7ef3c8eeb77b8d05, "33919492217977303", 304 },
        { 0x7ef5bc471d5456c7, "37263572163337027", 304 },
        { 0x7f03c8eeb77b8d05, "6783898443595461", 304 },
        { 0x7f13c8eeb77b8d05, "13567796887190921", 305 },
        { 0x7f23c8eeb77b8d05, "27135593774381842", 305 },
        { 0x7f33c8eeb77b8d05, "54271187548763685", 305 },
        { 0x7f5594223f5654bf, "2367662756557091", 306 },
        { 0x7f6594223f5654bf, "4735325513114182", 306 },
        { 0x7f9914e03c9260ee, "44032152438472327", 307 },
        { 0x7fb82baa4ae611dc, "16973149506391291", 308 },
        { 0x7fc82baa4ae611dc, "33946299012782582", 308 },
        { 0x7fd82baa4ae611dc, "67892598025565165", 308 },
        { 0x7fefffffffffffff, "17976931348623157", 309 },
    ];

    short low;
    short high = pathologies.length - 1;
    const FloatBits!double bits = { value };

    while (high >= low)
    {
        const short middle = (low + high) / 2;
        if (pathologies[middle].representation == bits.integral)
        {
            exponent = pathologies[middle].exponent;
            tanya.memory.op.copy(pathologies[middle].digits, buffer);
            return buffer[0 .. pathologies[middle].digits.length];
        }
        else if (pathologies[middle].representation < bits.integral)
        {
            low = cast(short) (middle + 1);
        }
        else
        {
            high = cast(short) (middle - 1);
        }
    }
    return null;
}

@nogc nothrow pure @safe unittest
{
    int exponent;
    char[512] buffer;

    assert(errol3(double.max, buffer, exponent) == "17976931348623157");
    assert(exponent == 309);

    assert(errol3(0.67892598025565165e308, buffer, exponent) == "67892598025565165");
    assert(exponent == 308);

    assert(errol3(0.40526371999771488e-307, buffer, exponent) == "40526371999771488");
    assert(exponent == -307);

    assert(errol3(0.81052743999542975e-307, buffer, exponent) == "81052743999542975");
    assert(exponent == -307);

    assert(errol3(0.810307, buffer, exponent) is null);
}

/*
 * Given a float value, returns the significant bits, and the position of the
 * decimal point in $(D_PARAM exponent). +/-Inf and NaN are specified by
 * special values returned in the $(D_PARAM exponent). Sing bit is set in
 * $(D_PARAM sign).
 */
private const(char)[] real2String(double value,
                                  return ref char[512] buffer,
                                  out int exponent,
                                  out bool sign) @nogc nothrow pure @trusted
{
    const FloatBits!double bits = { value };

    exponent = (bits.integral >> 52) & 0x7ff;
    sign = signBit(value);
    if (sign)
    {
        value = -value;
    }

    if (exponent == 0x7ff) // Is NaN or Inf?
    {
        exponent = special;
        return (bits.integral & ((1UL << 52) - 1)) != 0 ? "NaN" : "Inf";
    }
    else if (exponent == 0 && (bits.integral << 1) == 0) // Is zero?
    {
        exponent = 1;
        buffer[0] = '0';
        return buffer[0 .. 1];
    }

    auto digits = errol3(value, buffer, exponent);
    if (digits !is null)
    {
        return buffer;
    }
    else if (value >= 16.0 && value <= 9.007199254740992e15)
    {
        return errolFixed(value, buffer, exponent);
    }
    else if (value > 9.007199254740992e15 && value < 3.40282366920938e38)
    {
        return errol2(value, buffer, exponent);
    }
    else
    {
        return errol1(value, buffer, exponent);
    }
}

private void formatReal(T, OR)(ref T arg, OR result)
if (isFloatingPoint!T)
{
    char[512] buffer; // Big enough for e+308 or e-307.
    char[8] tail = 0;
    char[] bufferSlice = buffer[64 .. $];
    uint precision = 6;
    bool negative;
    int decimalPoint;

    // Read the double into a string.
    auto realString = real2String(arg, buffer, decimalPoint, negative);
    auto length = cast(uint) realString.length;

    // Clamp the precision and delete extra zeros after clamp.
    uint n = precision;
    if (length > precision)
    {
        length = precision;
    }
    while ((length > 1) && (precision != 0) && (realString[length - 1] == '0'))
    {
        --precision;
        --length;
    }

    if (negative)
    {
        put(result, "-");
    }
    if (decimalPoint == special)
    {
        put(result, realString);
        return;
    }

    // Should we use sceintific notation?
    if ((decimalPoint <= -4) || (decimalPoint > cast(int) n))
    {
        if (precision > length)
        {
            precision = length - 1;
        }
        else if (precision > 0)
        {
           // When using scientific notation, there is one digit before the
           // decimal.
           --precision;
        }

        // Handle leading chars.
        bufferSlice.front = realString[0];
        bufferSlice.popFront();

        if (precision != 0)
        {
            bufferSlice.front = period;
            bufferSlice.popFront();
        }

        // Handle after decimal.
        if ((length - 1) > precision)
        {
            length = precision + 1;
        }
        tanya.memory.op.copy(realString[1 .. length], bufferSlice);
        bufferSlice.popFrontExactly(length - 1);

        // Dump the exponent.
        tail[1] = 'e';
        --decimalPoint;
        if (decimalPoint < 0)
        {
            tail[2] = '-';
            decimalPoint = -decimalPoint;
        }
        else
        {
            tail[2] = '+';
        }

        n = decimalPoint >= 100 ? 5 : 4;

        tail[0] = cast(char) n;
        while (true)
        {
            tail[n] = '0' + decimalPoint % 10;
            if (n <= 3)
            {
                break;
            }
            --n;
            decimalPoint /= 10;
        }
    }
    else
    {
        if (decimalPoint > 0)
        {
            precision = decimalPoint < (cast(int) length)
                      ? length - decimalPoint
                      : 0;
        }
        else
        {
            precision = -decimalPoint
                      + (precision > length ? length : precision);
        }

        // Handle the three decimal varieties.
        if (decimalPoint <= 0)
        {
            // Handle 0.000*000xxxx.
            bufferSlice.front = '0';
            bufferSlice.popFront();

            if (precision != 0)
            {
                bufferSlice.front = period;
                bufferSlice.popFront();
            }
            n = -decimalPoint;
            if (n > precision)
            {
                n = precision;
            }

            tanya.memory.op.fill!'0'(bufferSlice[0 .. n]);
            bufferSlice.popFrontExactly(n);

            if ((length + n) > precision)
            {
                length = precision - n;
            }

            tanya.memory.op.copy(realString[0 .. length], bufferSlice);
            bufferSlice.popFrontExactly(length);
        }
        else if (cast(uint) decimalPoint >= length)
        {
            // Handle xxxx000*000.0.
            n = 0;
            do
            {
                bufferSlice.front = realString[n];
                bufferSlice.popFront();
                ++n;
            }
            while (n < length);
            if (n < cast(uint) decimalPoint)
            {
                n = decimalPoint - n;

                tanya.memory.op.fill!'0'(bufferSlice[0 .. n]);
                bufferSlice.popFrontExactly(n);
            }
            if (precision != 0)
            {
                bufferSlice.front = period;
                bufferSlice.popFront();
            }
        }
        else
        {
            // Handle xxxxx.xxxx000*000.
            n = 0;
            do
            {
                bufferSlice.front = realString[n];
                bufferSlice.popFront();
                ++n;
            }
            while (n < cast(uint) decimalPoint);

            if (precision > 0)
            {
                bufferSlice.front = period;
                bufferSlice.popFront();
            }
            if ((length - decimalPoint) > precision)
            {
                length = precision + decimalPoint;
            }

            tanya.memory.op.copy(realString[n .. length], bufferSlice);
            bufferSlice.popFrontExactly(length - n);
        }
    }

    // Get the length that we've copied.
    length = cast(uint) (buffer.length - bufferSlice.length);

    put(result, buffer[64 .. length]); // Number.
    put(result, tail[1 .. tail[0] + 1]); // Tail.
}

private void formatStruct(T, OR)(ref T arg, OR result)
if (is(T == struct))
{
    template pred(alias f)
    {
        static if (f == "this")
        {
            // Exclude context pointer from nested structs.
            enum bool pred = false;
        }
        else
        {
            enum bool pred = !isSomeFunction!(__traits(getMember, arg, f));
        }
    }
    alias fields = Filter!(pred, __traits(allMembers, T));

    put(result, T.stringof);
    put(result, "(");
    static if (fields.length > 0)
    {
        printToString!"{}"(result, __traits(getMember, arg, fields[0]));
        foreach (field; fields[1 .. $])
        {
            put(result, ", ");
            printToString!"{}"(result, __traits(getMember, arg, field));
        }
    }
    put(result, ")");
}

private void formatRange(T, OR)(ref T arg, OR result)
if (isInputRange!T && !isInfinite!T)
{
    put(result, "[");
    if (!arg.empty)
    {
        printToString!"{}"(result, arg.front);
        arg.popFront();
    }
    foreach (e; arg)
    {
        put(result, ", ");
        printToString!"{}"(result, e);
    }
    put(result, "]");
}

private void printToString(string fmt, OR, Args...)(ref OR result,
                                                    auto ref Args args)
{
    alias Arg = Args[0];

    static if (is(Unqual!Arg == typeof(null))) // null
    {
        put(result, "null");
    }
    else static if (is(Unqual!Arg == bool)) // Boolean
    {
        put(result, args[0] ? "true" : "false");
    }
    else static if (is(Arg == enum)) // Enum
    {
        foreach (m; __traits(allMembers, Arg))
        {
            if (args[0] == __traits(getMember, Arg, m))
            {
                put(result, m);
            }
        }
    }
    else static if (isSomeChar!Arg || isSomeString!Arg) // String or char
    {
        put(result, args[0]);
    }
    else static if (isInputRange!Arg
                 && !isInfinite!Arg
                 && isSomeChar!(ElementType!Arg)) // Stringish range
    {
        put(result, args[0]);
    }
    else static if (isInputRange!Arg && !isInfinite!Arg)
    {
        formatRange(args[0], result);
    }
    else static if (is(typeof(args[0].toString(result)) == OR))
    {
        static if (is(Arg == class) || is(Arg == interface))
        {
            if (args[0] is null)
            {
                put(result, "null");
            }
            else
            {
                result = args[0].toString(result);
            }
        }
        else
        {
            result = args[0].toString(result);
        }
    }
    else static if (is(Arg == class))
    {
        put(result, args[0] is null ? "null" : args[0].toString());
    }
    else static if (is(Arg == interface))
    {
        put(result, Arg.classinfo.name);
    }
    else static if (is(Arg == struct))
    {
        formatStruct(args[0], result);
    }
    else static if (is(Arg == union))
    {
        put(result, Arg.stringof);
    }
    else static if (isFloatingPoint!Arg) // Float
    {
        formatReal(args[0], result);
    }
    else static if (isPointer!Arg) // Pointer
    {
        char[size_t.sizeof * 2] buffer;
        size_t position = buffer.length;
        auto address = cast(size_t) args[0];

        do // Write at least "0" if the pointer is null.
        {
            buffer[--position] = lowerHexDigits[cast(size_t) (address & 15)];
            address >>= 4;
        }
        while (address != 0);

        put(result, "0x");
        put(result, buffer[position .. $]);
    }
    else static if (isIntegral!Arg) // Integer
    {
        char[21] buffer;
        put(result, integral2String(args[0], buffer));
    }
    else
    {
        static assert(false,
                      "Formatting type " ~ Arg.stringof ~ " is not supported");
    }
}

/**
 * Produces a string according to the specified format.
 *
 * Params:
 *  fmt  = Format.
 *  Args = Types of the arguments.
 *  args = Arguments.
 *
 * Returns: Formatted string.
 */
String format(string fmt, Args...)(auto ref Args args)
{
    String formatted;
    sformat!fmt(backInserter(formatted), args);
    return formatted;
}

/**
 * Produces a string according to the specified format and writes it into an
 * output range. $(D_PSYMBOL sformat) writes the final string in chunks, so the
 * output range should be in output range for `const(char)[]`.
 *
 * Params:
 *  fmt    = Format.
 *  R      = Output range type.
 *  output = Output range.
 *  args   = Arguments.
 *
 * Returns: $(D_PARAM output).
 */
R sformat(string fmt, R, Args...)(R output, auto ref Args args)
if (isOutputRange!(R, const(char)[]))
{
    alias Specs = ParseFmt!fmt;
    enum bool FormatSpecFilter(alias spec) = is(typeof(spec) == FormatSpec);
    static assert((Filter!(FormatSpecFilter, ParseFmt!fmt)).length == Args.length,
                  "Number of the arguments doesn't match the format string");

    foreach (spec; Specs)
    {
        static if (FormatSpecFilter!spec)
        {
            printToString!"{}"(output, args[spec.position]);
        }
        else static if (isSomeString!(typeof(spec)))
        {
            put(output, spec);
        }
        else
        {
            static assert(false, "Format string parsed incorrectly");
        }
    }
    return output;
}

private struct FormatSpec
{
    const size_t position;
}

// Returns the position of `tag` in `fmt`. If `tag` can't be found, returns the
// length of  `fmt`.
private size_t specPosition(string fmt, char tag)()
{
    foreach (i, c; fmt)
    {
        if (c == tag)
        {
            return i;
        }
    }
    return fmt.length;
}

private template ParseFmt(string fmt, size_t arg = 0, size_t pos = 0)
{
    static if (fmt.length == 0)
    {
        alias ParseFmt = AliasSeq!();
    }
    else static if (fmt[0] == '{')
    {
        static if (fmt.length > 1 && fmt[1] == '{')
        {
            enum size_t pos = specPosition!(fmt[2 .. $], '{') + 2;
            alias ParseFmt = AliasSeq!(fmt[1 .. pos],
                                       ParseFmt!(fmt[pos .. $], arg, pos));
        }
        else
        {
            enum size_t pos = specPosition!(fmt[1 .. $], '}') + 1;
            static if (pos >= fmt.length)
            {
                static assert(false, "Enclosing '}' is missing");
            }
            else static if (pos == 1)
            {
                alias ParseFmt = AliasSeq!(FormatSpec(arg),
                                           ParseFmt!(fmt[2 .. $], arg + 1, 2));
            }
            else
            {
                static assert(false, "Argument formatting isn't supported");
            }
        }
    }
    else
    {
        enum size_t pos = specPosition!(fmt, '{');
        alias ParseFmt = AliasSeq!(fmt[0 .. pos],
                                   ParseFmt!(fmt[pos .. $], arg, pos));
    }
}

@nogc nothrow pure @safe unittest
{
    static assert(ParseFmt!"".length == 0);

    static assert(ParseFmt!"asdf".length == 1);
    static assert(ParseFmt!"asdf"[0] == "asdf");

    static assert(ParseFmt!"{}".length == 1);

    static assert(ParseFmt!"aasdf{}qwer"[2] == "qwer");
    static assert(ParseFmt!"{}{}".length == 2);
}
