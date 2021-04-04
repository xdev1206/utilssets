#!/system/bin/sh
mapdir=/data/camera
facepid=`ps | grep -i facerecognition | sed -E "s/[ ]+/ /g" | cut -d' ' -f2`
mediapid=`ps | grep -i mediaserver | sed -E "s/[ ]+/ /g" | cut -d' ' -f2`

if [ "$facepid" == "" ]; then
    echo "no facerecognition process, exit!"
    exit 1
fi

if [ "$mediapid" == "" ]; then
    echo "no media process, exit!"
    exit 1
fi


echo "facerecognition pid: $facepid"
echo "media pid: $mediapid"

if [ ! -d $mapdir ]; then
    echo "mkdir -p $mapdir"
    mkdir -p $mapdir
fi

for i in `seq 1 100`
do
    echo "cat /proc/$facepid/maps > $mapdir/maps_${facepid}_$i";
    cat /proc/$facepid/maps > $mapdir/app_${facepid}_$i;

    echo "cat /proc/$mediapid/maps > $mapdir/maps_${mediapid}_$i";
    cat /proc/$mediapid/maps > $mapdir/media_${mediapid}_$i;
    sleep 4;
done
