#! /bin/bash

set -e

INF="\033[34;3m"
ERR="\033[31;1m"
MES="\033[32;1m"
DEF="\033[0m"

mkdir -p final
mkdir -p input
mkdir -p input_frames
mkdir -p output
mkdir -p output_frames

if [ ! -f rife/rife-ncnn-vulkan ]; then
    echo -e "${ERR}RIFE not detected in directory 'rife/', please download it from https://github.com/jadelweiss/Simple-Interpolator ${DEF}"
fi

DAT=`date '+%d/%m/%y_%H:%M:%S'`

mkdir -p recovered/"DAT"
[ ! -f *.mp4 ] || mv *.mp4 recovered/"DAT"
[ ! -f *.m4a ] || mv *.m4a recovered/"DAT"

while [ `ls output_frames/ | wc -l` != 0 ];
do
    cd output_frames
    ls | head -32768 | xargs rm -f
    cd ..
    echo -e "${INF}Removed 32,768 output frames${DEF}"
done

while [ `ls input_frames/ | wc -l` != 0 ];
do
    cd input_frames
    ls | head -32768 | xargs rm -f
    cd ..
    echo -e "${INF}Removed 32,768 input frames${DEF}"
done

tally=0
cfgdir=`cat config.txt | head -1`
recurseln=`cat config.txt | grep recursive`
recurse=${recurseln##*=}
targetfps=`cat config.txt | tail -1`
if [ "$recurse" == "true" ]; then
    echo -e "${MES}Recursive (auto) mode active${DEF}"
    for dir in $(find input/ -maxdepth 1 -mindepth 1 -type d);
    do
        count=`ls $dir | grep .mp4 | wc -l` >> log.txt
        count=`ls $dir | grep .mp4 | wc -l` >> logall.txt
        if [ "$count" == 0 ]; then
            rm -r "$dir"
        fi
    done
    if [ `ls input/ | grep .mp4 | wc -l` == 0 ]; then
        indir=`ls input/ | head -1`
        echo $indir | tee -a log.txt
        echo $indir >> logall.txt
        inpath=`echo $indir/`
        input=`ls input/"$indir" | grep .mp4 | head -1` >> log.txt
        input=`ls input/"$indir" | grep .mp4 | head -1` >> logall.txt
        mv input/"$indir"/"$input" .
    else
        input=`ls input/ | grep .mp4 | head -1` >> log.txt
        input=`ls input/ | grep .mp4 | head -1` >> logall.txt
        mv input/"$input" .
    fi
else
    if [ "$cfgdir" == "" ]; then
        if [ `ls input/ | grep .mp4 | wc -l` == 0 ]; then
            for dir in $(find input/ -maxdepth 1 -mindepth 1 -type d);
            do
                count=`ls $dir | grep .mp4 | wc -l` >> log.txt
                count=`ls $dir | grep .mp4 | wc -l` >> logall.txt
                if [ "$count" == 0 ]; then
                    rm -r "$dir"
                else
                    dir=${dir##*/}
                    tally=$(($tally+1))
                    echo "$tally. $dir ($count)" | tee -a log.txt
                    echo "$tally. $dir ($count)" >> logall.txt
                fi
            done
            if [ "$tally" -gt 1 ]; then
                read -p "Choose target directory:" key
                indir=`ls input/ | head -"$key" | tail -1`
                echo $indir | tee -a log.txt
                echo $indir >> logall.txt
                echo $indir > config.txt
                inpath=`echo $indir/`
                input=`ls input/"$indir" | grep .mp4 | head -1` >> log.txt
                input=`ls input/"$indir" | grep .mp4 | head -1` >> logall.txt
                mv input/"$indir"/"$input" .
            elif [ "$tally" == 1 ]; then
                indir=`ls input/`
                echo $indir | tee -a log.txt
                echo $indir >> logall.txt
                inpath=`echo $indir/`
                input=`ls input/"$indir" | grep .mp4 | head -1` >> log.txt
                input=`ls input/"$indir" | grep .mp4 | head -1` >> logall.txt
                mv input/"$indir"/"$input" .
            fi
        else
            input=`ls input/ | grep .mp4 | head -1` >> log.txt
            input=`ls input/ | grep .mp4 | head -1` >> logall.txt
            mv input/"$input" .
        fi
    else
        echo -e "${INF}Pulling from config...${DEF}"
        echo "Pulling from config..." >> log.txt
        echo "Pulling from config..." >> logall.txt
        if [ `ls input/$cfgdir | grep .mp4 | wc -l` == 0 ]; then
            saved=`cat config.txt | tail -2 | head -1`
            echo "" > config.txt
            echo $saved >> config.txt
            ./run.sh
        else
            input=`ls input/"$cfgdir" | grep .mp4 | head -1`
            indir="$cfgdir"
            inpath=`echo $indir/`
            mv input/"$cfgdir"/"$input" .
        fi
    fi
fi
echo $input

if [ "$inpath" != "" ]; then
    mkdir -p output/"$indir"
    mkdir -p final/"$indir"
fi

if [ "$input" == "" ]; then
    echo -e "${MES}Input Directory Empty${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT Input Directory Empty" >> log.txt
    echo "$DAT Input Directory Empty" >> logall.txt
    exit 0
fi

echo -e "${MES}New Process${DEF}"
DAT=`date '+%d/%m/%y_%H:%M:%S'`
echo "$DAT ---- New Process ----" >> log.txt
echo "$DAT ---- New Process ----" >> logall.txt

fps=`ffprobe "$input" 2>&1 | grep "fps"`
echo $fps >> log.txt
echo $fps >> logall.txt
yuv=`ffprobe "$input" 2>&1 | grep -o "yuv4..."`
#echo $yuv >> log.txt
lib=`ffprobe "$input" 2>&1 | grep -o "h26."`
#echo $lib >> log.txt
lib=${lib##*h}
#echo $lib >> log.txt
fps=${fps%fps*}
#echo $fps >> log.txt
fps=${fps##*,}
#echo $fps >> log.txt
fpsi=`echo "$fps * 100" | bc -l`
#echo $fpsi >> log.txt
fpsi=${fpsi%.*}
#echo $fpsi >> log.txt

targetfps=${targetfps##*=}
if [ $targetfps == 120 ]; then
    lttarget=8000
    mult=$((12000000000/$fpsi))
    over=80
    outdir="processed120"
    ffrate=120
else
    lttarget=5000
    mult=$((6000000000/$fpsi))
    over=50
    outdir="processed60"
    ffrate=60
fi

if [ $fpsi -lt $lttarget ]; then

    echo -e "${INF}Starting audio extraction${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT Starting audio extraction" >> log.txt
    echo "$DAT Starting audio extraction" >> logall.txt
    ffmpeg -i "$input" -vn -acodec copy audio.m4a

    echo -e "${INF}Decompiling frames${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT Decompiling frames" >> log.txt
    echo "$DAT Decompiling frames" >> logall.txt
    ffmpeg -i "$input" input_frames/frame_%08d.png

    frame_count=`ls -1 input_frames/ | wc -l`
    
    output_count=$(((($frame_count*$mult)+500000)/1000000))

    echo -e "${INF}Interpolating $frame_count -> $output_count frames${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT Interpolating $frame_count -> $output_count frames" >> log.txt
    echo "$DAT Interpolating $frame_count -> $output_count frames" >> logall.txt
    ./rife/rife-ncnn-vulkan -i input_frames -o output_frames -n $output_count -m rife-v4.6 -v #2>&1 | grep --line-buffered -o "output_frames/........" | grep --line-buffered -o "00......"

    echo -e "${INF}Recompiling video${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT Recompiling video" >> log.txt
    echo "$DAT Recompiling video" >> logall.txt
    ffmpeg -f image2 -framerate "$ffrate" -thread_queue_size 1024 -i output_frames/%08d.png -crf 16 -c:v libx"$lib" -pix_fmt "$yuv" output/"$inpath""$input" -y

    echo -e "${INF}Splicing audio${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT Splicing audio" >> log.txt
    echo "$DAT Splicing audio" >> logall.txt
    ffmpeg -i output/"$inpath""$input" -i audio.m4a -c:v copy -map 0:v:0 -map 1:a:0 -b:a 256k final/"$inpath""$input" -y
    
    mkdir -p ../"$outdir"/"$inpath"
    cp final/"$inpath""$input" ../"$outdir"/"$inpath""$input"
else
    cp "$input" output/"$inpath""$input"
    cp "$input" final/"$inpath""$input"
    echo -e "${INF}$input was over $over fps${DEF}"
    DAT=`date '+%d/%m/%y_%H:%M:%S'`
    echo "$DAT $input was over $over fps" >> log.txt
    echo "$DAT $input was over $over fps" >> logall.txt
fi

echo -e "${MES}Process Completed${DEF}"
DAT=`date '+%d/%m/%y_%H:%M:%S'`
echo "$DAT ---- Process Completed ----" >> log.txt
echo "$DAT ---- Process Completed ----" >> logall.txt
echo "" >> log.txt
echo "" >> logall.txt

./run.sh
