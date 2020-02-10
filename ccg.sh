#!/bin/bash

## ${x:$((${#x}-3))}

## INIT

S_PAGES=3
S_TMP=/tmp/vDrop_1
S_REQUEST=cats
S_MIN_LENGTH="00:00:10.00"
S_OUT_LOG=/dev/null

C_COUB_API="http://coub.com/api/v2/search/coubs"
C_RESP_BUFFER=resp_buffer

C_MERGED_MP4="MERGED.mp4"
C_MERGED_MP3="MERGED.mp3"
C_OUTPUT="output.mp4"
C_INTRO4="LC_INTRO.mp4"
C_OUTRO4="LC_OUTRO.mp4"
C_INTRO3="LC_INTRO.mp3"
C_OUTRO3="LC_OUTRO.mp3"

function error
{
    echo "[  ERROR  ] $1"
    echo "Continue? [y/any]:"
    read c
    [[ $c != "y" ]] && exit 1
}

function log
{
    echo "[ PROGRES ] $1"
}

## MAIN

function id
{
    local resource=$1

    resource=${resource##*/}
    printf "${resource::3}"
}

function coub_api_request
{
    local page=$1

    log "coub_api_request(): Requesting JSON for page $page"
    local request="$C_COUB_API?q=$S_REQUEST&order_by=newest&page=$page"

    curl -s "$request" > "$S_TMP/$C_RESP_BUFFER"
    log "coub_api_request(): Recived to $S_TMP/$C_RESP_BUFFER"
}

function json_value
{
    local buffer=$1
    local key=$2

    log "get_json_value(): Invoking jq for get $key"
    eval $buffer=$(cat "$S_TMP/$C_RESP_BUFFER" | jq -r "$key")
}

function json_video_url
{
    local buffer=$1
    local index=$2
    
    eval $buffer=".coubs[$index].file_versions.html5.video.higher.url"
}

function json_audio_url
{
    local buffer=$1
    local index=$2

    eval $buffer=".coubs[$index].file_versions.html5.audio.high.url"
}

function donwload_page
{
    local page=$1

    log "donwload_page(): Downloading page $page"
    local amount
    json_value amount .per_page
    log "donwload_page(): Amount: $amount"

    local c
    for ((c=0; c < $amount; c++))
    do
        local video_url
        local audio_url
        local video_url_key
        local audio_url_key

        json_video_url video_url_key $c
        json_audio_url audio_url_key $c

        json_value video_url $video_url_key
        json_value audio_url $audio_url_key

        log "donwload_page(): Downloading video $c..."
        wget -O "$S_TMP/${page}_$c.mp4" $video_url 2&>1 > $S_OUT_LOG
        log "donwload_page(): Downloading audio $c..."
        wget -O "$S_TMP/${page}_$c.mp3" $audio_url 2&>1 > $S_OUT_LOG
    done
}

function donwload_all 
{
    log "donwload_all(): Start"

    local c
    for ((c=0; c < $S_PAGES; c++))
    do
        coub_api_request $c
        donwload_page $c
    done
}

function scale
{
    local video=$1

    log "scale(): Scaling $video..."
    ffmpeg -i "$video" -vf \
        "scale=iw*min(1920/iw\,1080/ih):ih*min(1920/iw\,1080/ih),
        pad=1920:1080:(1920-iw*min(1920/iw\,1080/ih))/2:(1080-ih*
        min(1920/iw\,1080/ih))/2" -r 60 "$S_TMP/$(id $video).tmp.mp4"

    rm $video
    mv "$S_TMP/$(id $video).tmp.mp4" $video

    log "scale(): $video was scaled"
}

function scale_all
{
    local video

    log "scale_all(): Scaling all in $S_TMP"
    for video in $S_TMP/*.mp4
    do
        scale $video
    done

    log "scale_all(): Removing useless audio"
    for audio in $S_TMP/*.mp3
    do
        [[ ! -f $S_TMP/$(id $audio).mp4 ]] && rm $audio
    done
}

function duration
{
    local media=$1

    local dur=$(ffmpeg -i $media 2>&1 | grep Duration)
    printf "${dur:12:11}"
}

function fit
{
    local media=$1
    local to=$2
    local pfx=$3

    log "fit(): Fittig $media to $to with postfix $pfx"

    while [[ $(duration $media) < $to ]]
    do
        log "fit(): Duration is $(duration $media), not enough"
        local m_id=$(id $media)

        printf "file '$media'\nfile '$media'\n" > "$S_TMP/__"
        ffmpeg -f concat -safe 0 -i "$S_TMP/__" "$S_TMP/$(id $media).tmp$pfx"
        rm $video
        mv "$S_TMP/$m_id.tmp$pfx" "$media"
        rm "$S_TMP/__"
    done

    log "fit(): Done"
}

function fit_audio
{
    local audio=$1

    local to=$(duration "$S_TMP/$(id $audio).mp4")
    log "fit_audio(): Fitting $audio to $to"
    fit $audio $to ".mp3"

    log "fit_audio(): Cut $audio to $to"
    ffmpeg -i $audio -c copy -t $to $audio.tmp.mp3
    rm $audio
    mv "$audio.tmp.mp3" $audio
}

function fit_all
{
    log "fit_all(): Fitting all video in $S_TMP"
    for video in $S_TMP/*.mp4
    do
        fit $video $S_MIN_LENGTH .mp4
    done

    log "fit_all(): Fitting all audio in $S_TMP"
    for audio in $S_TMP/*.mp3
    do
        fit_audio $audio
    done
}

function copy_io
{
    log "copy_io(): Copying intros/outros to $S_TMP if need"
    # TODO: Replace ~ with $HOME constant
    [[ ! -f "$S_TMP/$C_INTRO4" ]] && cp ~/Videos/$C_INTRO4 "$S_TMP/"
    [[ ! -f "$S_TMP/$C_OUTRO4" ]] && cp ~/Videos/$C_OUTRO4 "$S_TMP/"
    [[ ! -f "$S_TMP/$C_INTRO3" ]] && cp ~/Videos/$C_INTRO3 "$S_TMP/"
    [[ ! -f "$S_TMP/$C_OUTRO3" ]] && cp ~/Videos/$C_OUTRO3 "$S_TMP/"
}

function merge_video
{
    copy_io

    log "merge_video(): Writing tmp file"
    printf "file '$S_TMP/$C_INTRO4'\n" > $S_TMP/__

    for video in $S_TMP/*.mp4
    do
        [[ $(id $video) == "LC_" ]] && continue
        printf "file '$video'\n" >> $S_TMP/__
    done

    printf "file '$S_TMP/$C_OUTRO4'\n" >> $S_TMP/__

    ffmpeg -f concat -safe 0 -i $S_TMP/__ $S_TMP/$C_MERGED_MP4

}

function merge_audio
{
    copy_io

    log "merge_audio(): Writing tmp file"
    printf "file '$S_TMP/$C_INTRO3'\n" > $S_TMP/__

    # The 'find' util with '-exec' parameter will do the same operation
    # but in unsorted order
    for audio in $S_TMP/*.mp3
    do
        [[ $(id $audio) == "LC_" ]] && continue
        printf "file '$audio'\n" >> $S_TMP/__
    done

    printf "file '$S_TMP/$C_OUTRO3'\n" >> $S_TMP/__

    ffmpeg -f concat -safe 0 -i $S_TMP/__ $S_TMP/$C_MERGED_MP3
}

function merge
{
    log "merge(): Merge audio & video of coubs"
    ffmpeg -i $S_TMP/$C_MERGED_MP4 -i $S_TMP/$C_MERGED_MP3 \
        -c copy $S_TMP/$C_OUTPUT
return 
    log "merge(): Merge final video"
    printf \
    "file '$S_TMP/$C_INTRO'\nfile '$S_TMP/$C_OUTPUT'\nfile '$S_TMP/$C_OUTRO" \
    > $S_TMP/__

    ffmpeg -f concat -safe 0 -i $S_TMP/__ $S_TMP/$C_OUTPUT.tmp.mp4
    rm $S_TMP/$C_OUTPUT
    mv $S_TMP/$C_OUTPUT.tmp.mp4 $S_TMP/$C_OUTPUT
}

function start
{
    log "start(): Creating $S_TMP if need"
    [[ ! -d $S_TMP ]] && mkdir "$S_TMP"
}

function clean
{
    log "clean(): Cleaning..."
    rm -rf "$S_TMP"
}

## WRAPPING

function _pages
{
    S_PAGES=$1
}

function _tmp
{
    S_TMP=$1
}

function _request
{
    S_REQUEST=$1
}

start

_nextfoo=null
for arg in $@
do
    if [ $_nextfoo != null ]
    then
        $_nextfoo $arg
        _nextfoo=null
    else
        case "$arg" in
            "-p")
                _nextfoo="_pages"
                ;;
            "-t")
                _nextfoo="_tmp"
                ;;
            "-r")
                _nextfoo="_request"
                ;;
            "-c")
                clean
                ;;
            "-d") # Download all
                donwload_all
                ;;
            "-s") # Scale all
                scale_all
                ;;
            "-f") # Fit all
                fit_all
                ;;
            "-v") # Merge videotrack
                merge_video
                ;;
            "-a") # Merge audiotrack
                merge_audio
                ;;
            "-m") # Merge coubs
                merge
                ;;
            "-j") # Equal to -d -s -v -a -m
                donwload_all
                scale_all
                fit_all
                merge_video
                merge_audio
                merge
                ;;
            *)
                error "Invalid argument: $arg"
        esac
    fi
done
