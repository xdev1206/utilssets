#!/system/bin/sh

fw_path=/system/framework

while getopts "br" optn; do
    case $optn in
    b)
	cp ${fw_path}/services.jar ${fw_path}/services.jar.bak;
	cp ${fw_path}/framework.jar ${fw_path}/framework.jar.bak;
	cp ${fw_path}/android.policy.jar ${fw_path}/android.policy.jar.bak;
	cp ${fw_path}/tv.whaley.utils.jar ${fw_path}/tv.whaley.utils.jar.bak;
	exit 0;;
    r)
	cp ${fw_path}/services.jar.bak ${fw_path}/services.jar;
	cp ${fw_path}/framework.jar.bak ${fw_path}/framework.jar;
	cp ${fw_path}/android.policy.jar.bak ${fw_path}/android.policy.jar;
	cp ${fw_path}/tv.whaley.utils.jar.bak ${fw_path}/tv.whaley.utils.jar;
	exit 0;;
    ?)
	echo "note : illegal argument!";
	exit 0;;
    esac
done

echo "$0"
echo "usage:"
echo "    -b backup fw jars"
echo "    -r restor fw jars"
