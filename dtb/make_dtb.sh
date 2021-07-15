#!/bin/sh

set -e

# prerequisites: build-essential device-tree-compiler
# kernel.org linux version
lv='5.13.2'

if [ -z "$1" ]; then

if [ ! -d "linux-$lv" ]; then
    if [ ! -f "linux-$lv.tar.xz" ]; then
        wget "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$lv.tar.xz"
    fi
    tar xJvf "linux-$lv.tar.xz" "linux-$lv/include" "linux-$lv/arch/arm64/boot/dts/rockchip"
fi

nanodts="linux-$lv/arch/arm64/boot/dts/rockchip/rk3399-nanopi-r4s.dts"
if [ ! -f "$nanodts.ori" ]; then
    cp "$nanodts" "$nanodts.ori"
fi

if ! grep -q 'r8169-100:00:link' "$nanodts"; then
    sed -i 's/label = "green:lan";/&\n\t\t\tlinux,default-trigger = "r8169-100:00:link";/' "$nanodts"
fi
if ! grep -q 'stmmac-0:01:link' "$nanodts"; then
    sed -i 's/label = "green:wan";/&\n\t\t\tlinux,default-trigger = "stmmac-0:01:link";/' "$nanodts"
fi

# see https://patchwork.kernel.org/project/linux-rockchip/patch/20210607081727.4723-1-cnsztl@gmail.com
if ! grep -q '&i2c2' "$nanodts"; then
    sed -i 's/\&i2c4 {/\&i2c2 {\
	eeprom@51 {\
		compatible = "microchip,24c02", "atmel,24c02";\
		reg = <0x51>;\
		pagesize = <16>;\
		size = <256>;\
		read-only;\
	};\
};\n\n&/' "$nanodts"
fi

# see https://patchwork.kernel.org/project/linux-rockchip/patch/20210705010424.72269-1-peterwillcn@gmail.com
if ! grep -q 'stdout-path = "serial2:1500000n8";' "$nanodts"; then
    sed -i 's/compatible = "friendlyarm,nanopi-r4s", "rockchip,rk3399";/&\n\
	chosen {\
		stdout-path = "serial2:1500000n8";\
	};/' "$nanodts"
fi

# see https://patchwork.kernel.org/project/linux-rockchip/patch/20210705010424.72269-1-peterwillcn@gmail.com
if ! grep -q '^&sdmmc {$' "$nanodts"; then
    sed -i 's/\&u2phy0_host {/\&sdmmc {\
	host-index-min = <1>;\
};\n\n&/' "$nanodts"
fi

# see https://patchwork.kernel.org/project/linux-rockchip/patch/20210705150327.86189-2-peterwillcn@gmail.com
if grep -q '^&vcc3v3_sys {$' "$nanodts"; then
    sed -i '/^&vcc3v3_sys {$/,/};/d' "$nanodts"
fi

fi # -z $1

case "$1" in
'clean')
    rm -f rk3399*
    rm -rf "linux-$lv"
    echo 'clean complete'
    ;;
'links')
    ln -s "linux-$lv/arch/arm64/boot/dts/rockchip/rk3399-nanopi-r4s.dts"
    ln -s "linux-$lv/arch/arm64/boot/dts/rockchip/rk3399-nanopi4.dtsi"
    ln -s "linux-$lv/arch/arm64/boot/dts/rockchip/rk3399.dtsi"
    ln -s "linux-$lv/arch/arm64/boot/dts/rockchip/rk3399-opp.dtsi"
    echo 'links created'
    ;;
*)
    # build
    gcc -I "linux-$lv/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o rk3399-nanopi-r4s-top.dts "linux-$lv/arch/arm64/boot/dts/rockchip/rk3399-nanopi-r4s.dts"
    dtc -O dtb -o rk3399-nanopi-r4s.dtb rk3399-nanopi-r4s-top.dts
    ;;
esac

