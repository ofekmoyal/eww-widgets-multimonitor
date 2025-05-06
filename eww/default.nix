#{pkgs ? import <nixpkgs> {}}:
#pkgs.stdenv.mkDerivation {
#  name = "muh-eww";
#  src = ./.;
#
#  buildInputs = with pkgs; [
#  ];
#
#  installPhase = ''
#    mkdir -p $out/bin
#    mkdir -p $out/share/muh-eww
#
#    # Copy your eww configuration files
#    cp -r $src/* $out/share/muh-eww/
#
#    # Create a wrapper script to run eww with your config
#    cat > $out/bin/muh-eww <<EOF
#    #!${pkgs.bash}/bin/bash
#    export PATH="${pkgs.coreutils}/bin:\$PATH"
#    export EWW_CONFIG=$out/share/muh-eww/bar/
#    export EWW_CONFIG_DIR=$out/share/muh-eww/bar/
#
#    export EWW_BINARY=${pkgs.eww}/bin/eww
#    export EWW_EXECUTABLE=${pkgs.eww}/bin/eww
#    ${pkgs.eww}/bin/eww --config $out/share/muh-eww/bar/ "\$@"
#    EOF
#
#    chmod +x $out/bin/muh-eww
#  '';
#}
# From here https://github.com/coffeeispower/nix-configuration/blob/b02675b15444533996fb023aea61eb017953b692/modules/home/eww/default.nix
{
  lib,
  config,
  pkgs,
  ...
}: {
  xdg.configFile."eww" = lib.mkIf config.programs.eww.enable {recursive = true;};
  home.packages = with pkgs;
    lib.mkIf config.programs.eww.enable [
      bluetui
      coreutils
      dunst
      dmenu
      eww
      ffmpeg
      impala
      mpc
      networkmanager
      playerctl
      socat
      icomoon-feather
      jetbrains-mono
      jq
      nerdfonts
      wireplumber
      (writeShellScriptBin "battery" ''
        battery() {
        	BAT=`ls /sys/class/power_supply | grep BAT | head -n 1`
        	cat /sys/class/power_supply/$BAT/capacity
        }
        battery_stat() {
        	BAT=`ls /sys/class/power_supply | grep BAT | head -n 1`
        	cat /sys/class/power_supply/$BAT/status
        }

        if [[ "$1" == "--bat" ]]; then
        	battery
        elif [[ "$1" == "--bat-st" ]]; then
        	battery_stat
        fi
      '')
      (writeShellScriptBin "cpu" ''
        PREV_TOTAL=0
        PREV_IDLE=0
        cpuFile="/tmp/.cpu_usage"

        get_cpu() {
        	if [[ -f "$cpuFile" ]]; then
        		fileCont=$(cat "$cpuFile")
        		PREV_TOTAL=$(echo "$fileCont" | head -n 1)
        		PREV_IDLE=$(echo "$fileCont" | tail -n 1)
        	fi

        	CPU=(`cat /proc/stat | grep '^cpu '`) # Get the total CPU statistics.
        	unset CPU[0]                          # Discard the "cpu" prefix.
        	IDLE=$CPU[4]                        # Get the idle CPU time.

        	# Calculate the total CPU time.
        	TOTAL=0

        	for VALUE in "$CPU[@]:0:4"; do
        		let "TOTAL=$TOTAL+$VALUE"
        	done

        	if [[ "$PREV_TOTAL" != "" ]] && [[ "$PREV_IDLE" != "" ]]; then
        		# Calculate the CPU usage since we last checked.
        		let "DIFF_IDLE=$IDLE-$PREV_IDLE"
        		let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
        		let "DIFF_USAGE=(1000*($DIFF_TOTAL-$DIFF_IDLE)/$DIFF_TOTAL+5)/10"
        		echo "$DIFF_USAGE"
        	else
        		echo "?"
        	fi

        	# Remember the total and idle CPU times for the next check.
        	echo "$TOTAL" > "$cpuFile"
        	echo "$IDLE" >> "$cpuFile"
        }
        get_cpu
      '')
      (writeShellScriptBin "test_workspace" ''
        echo $(hyprctl workspaces -j | jq '.[] | {id}' | jq --arg is_fill 1 '. + {"status": ($is_fill | tonumber)}' | jq -s '.' | jq -r 'sort_by(.id)')
        socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
          if [[ $line == *"workspace>>"* ]] || [[ $line == *"focusedmon>>"* ]]; then
            work=$(hyprctl workspaces -j | jq '.[] | {id}' | jq --arg is_fill 1 '. + {"status": ($is_fill | tonumber)}' | jq -s '.' | jq -r 'sort_by(.id)')
            max_id=$(echo $work | jq 'max_by(.id)' | jq '.id')
            for i in $(seq 1 $max_id)
              do
              test=$(echo "$work" | jq --arg query "$i" '.[] | select(.id == ($query | tonumber))')
              if [[ ! "$test" ]]; then
                work=$(echo $work | jq --arg ii $i '. + [{"id": ($ii | tonumber), "status": (0 | tonumber)}]' | jq -r 'sort_by(.id)')
              fi
            done
            echo $work
          fi
        done
      '')
      (writeShellScriptBin "poll_workspace" ''
        # Get initial workspace
        echo $(hyprctl -j activeworkspace | jq -r '.id')
        # Listen for workspace changes
        socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
          if [[ $line == *"workspace>>"* ]] || [[ $line == *"focusedmon>>"* ]]; then
            cur=$(hyprctl -j activeworkspace | jq -r '.id')
            eww update current_workspace=$cur
            echo $cur
          fi
        done
      '')
      (writeShellScriptBin "notifs" ''
        count="$(dunstctl count history)"

            if [ $count -gt 0 ]; then
                col="#0f0f17"
                bg="#bbc5d7"
                icon=""
            else
                bg="#0f0f17"
                col="#bbc5d7"
                echo ""
            fi



            if [ "$(dunstctl is-paused)" == "true" ]; then
                icon=""
                col="#d78787"
                bg="#0f0f17"
            fi


        if [ $1 = "notifs" ]; then
            echo $icon
        elif [ $1 = "notifs_col" ]; then
            echo $col
        elif [ $1 = "notifs_bg" ]; then
            echo $bg
        elif [ $1 = "toggle_notifs" ]; then
            dunstctl set-paused toggle
        fi
      '')
      (writeShellScriptBin "mem-ad" ''
        total="$(free -m | grep Mem: | awk '{ print $2 }')"
        used="$(free -m | grep Mem: | awk '{ print $3 }')"

        free=$(expr $total - $used)

        if [ "$1" = "total" ]; then
            echo $total
        elif [ "$1" = "used" ]; then
            echo $used
        elif [ "$1" = "free" ]; then
            echo $free
        fi
      '')
      (writeShellScriptBin "memory" ''
        printf "%.0f\n" $(free -m | grep Mem | awk '{print ($3/$2)*100}')
      '')
      (writeShellScriptBin "music_info" ''
        # scripts by adi1090x
        ## Get data
        STATUS="$(playerctl status)"
        MUSIC_DIR="$HOME/Music"

        ## Get status
        get_status() {
        	if [[ $STATUS == "Playing" ]]; then
        		echo "播放"
        	else
        		echo "暂停"
        	fi
        }

        ## Get song
        get_song() {
        	song=`playerctl metadata title`
        	if [[ -z "$song" ]]; then
        		echo "geen muziek"
        	else
        		echo "$song"
        	fi
        }

        ## Get artist
        get_artist() {
        	artist=`playerctl metadata artist`
        	if [[ -z "$artist" ]]; then
        		echo ""
        	else
        		echo "$artist"
        	fi
        }

        ## Get time
        get_time() {
        	time=`playerctl metadata --format '{{xesam:trackNumber}}'`
        	if [[ -z "$time" ]]; then
        		echo "0"
        	else
        		echo "$time"
        	fi
        }
        get_ctime() {
        	ctime=`mpc status | grep "#" | awk '{print $3}' | sed 's|/.*||g'`
        	if [[ -z "$ctime" ]]; then
        		echo "0:00"
        	else
        		echo "$ctime"
        	fi
        }
        get_ttime() {
        	ttime=`playerctl position`
        	if [[ -z "$ttime" ]]; then
        		echo "0:00"
        	else
        		echo "$ttime"
        	fi
        }

        ## Get cover
        get_cover() {
          COVER="/tmp/music_cover.png"
          art_url=$(playerctl metadata --format '{{ mpris:artUrl }}')
          if [[ $art_url == file://* ]]; then
            file_path=$(echo $art_url | sed 's/^file:\/\///')
            cp "$file_path" "$COVER"
          elif [[ $art_url == http* ]]; then
            wget "$art_url" -O "$COVER"       	# Check if the file has a embbeded album art
          fi
        	echo "$COVER"
        }

        ## Execute accordingly
        if [[ "$1" == "--song" ]]; then
        	get_song
        elif [[ "$1" == "--artist" ]]; then
        	get_artist
        elif [[ "$1" == "--status" ]]; then
        	get_status
        elif [[ "$1" == "--time" ]]; then
        	get_time
        elif [[ "$1" == "--ctime" ]]; then
        	get_ctime
        elif [[ "$1" == "--ttime" ]]; then
        	get_ttime
        elif [[ "$1" == "--cover" ]]; then
        	get_cover
        elif [[ "$1" == "--toggle" ]]; then
        	playerctl play-pause
        elif [[ "$1" == "--next" ]]; then
        	{ playerctl next; get_cover; }
        elif [[ "$1" == "--prev" ]]; then
        	{ playerctl previous; get_cover; }
        fi
      '')
      (writeShellScriptBin "pop" ''
        calendar() {
          LOCK_FILE="$HOME/.cache/eww-calendar.lock"

          run() {
            eww open calendar --screen 0
          }

        # Open widgets
        if [[ ! -f "$LOCK_FILE" ]]; then
            eww close system music_win audio_ctl
            touch "$LOCK_FILE"
            run && echo "ok good!"
        else
            eww close calendar
            rm "$LOCK_FILE" && echo "closed"
        fi
        }


        system() {
        LOCK_FILE_MEM="$HOME/.cache/eww-system.lock"
        EWW_BIN=$EWW_BINARY

        run() {
            eww open system --screen 0
        }

        # Open widgets
        if [[ ! -f "$LOCK_FILE_MEM" ]]; then
            eww close calendar music_win audio_ctl
            touch "$LOCK_FILE_MEM"
            run && echo "ok good!"
        else
            eww close system
            rm "$LOCK_FILE_MEM" && echo "closed"
        fi
        }


        music() {
          LOCK_FILE_SONG="$HOME/.cache/eww-song.lock"
          EWW_BIN=$EWW_BINARY

        run() {
            eww open music_win --screen 0
        }

        # Open widgets
        if [[ ! -f "$LOCK_FILE_SONG" ]]; then
            eww close system calendar
            touch "$LOCK_FILE_SONG"
            run && echo "ok good!"
        else
            eww close music_win
            rm "$LOCK_FILE_SONG" && echo "closed"
        fi
        }



        audio() {
        LOCK_FILE_AUDIO="$HOME/.cache/eww-audio.lock"
        EWW_BIN=$EWW_BINARY

        run() {
            eww open audio_ctl --screen 0
        }

        # Open widgets
        if [[ ! -f "$LOCK_FILE_AUDIO" ]]; then
            eww close system calendar music
            touch "$LOCK_FILE_AUDIO"
            run && echo "ok good!"
        else
            eww close audio_ctl
            rm "$LOCK_FILE_AUDIO" && echo "closed"
        fi
        }


        if [ "$1" = "calendar" ]; then
        calendar
        elif [ "$1" = "system" ]; then
        system
        elif [ "$1" = "music" ]; then
        music
        elif [ "$1" = "audio" ]; then
        audio
        fi
      '')
      (writeShellScriptBin "vol" ''
            cmd="$(amixer | grep 'Front Left:' | awk '{ print $6 }')"


            if [ "$cmd" == "[on]" ]; then
                col="#0f0f17"
                bg="#bbc5d7"
                icon=""
            else
                bg="#0f0f17"
                col="#bbc5d7"
                icon="󰓃"
            fi



        if [ $1 = "vol" ]; then
            echo $icon
        elif [ $1 = "vol_col" ]; then
            echo $col
        elif [ $1 = "vol_bg" ]; then
            echo $bg
        fi
      '')
      (writeShellScriptBin "wifi" ''
        status=$(nmcli g | grep -oE "disconnected")
        essid=$(nmcli c | grep wlp4s0 | awk '{print ($1)}')

        if [ $status ] ; then
            icon="󱍋"
            text="Disconnected"
            col="#575268"

        else
            icon=""
            text=$essid
            col="#a1bdce"
        fi

        if [[ "$1" == "--COL" ]]; then
            echo $col
        elif [[ "$1" == "--ESSID" ]]; then
        	echo $text
        elif [[ "$1" == "--ICON" ]]; then
        	echo $icon
        fi
      '')
      (writeShellScriptBin "wifi2" ''
            if [ "$(systemctl status NetworkManager | grep 'inactive')" ]; then
                icon=""
                col="#d78787"
                bg="#0f0f17"
            fi

            if [ "$(nmcli g | grep -oE 'disconnected')" ]; then
                icon="󱍋" # disconnected
                col="#bfc9db"
                bg="#0f0f17"
            else
                icon="" # connected
                col="#0f0f17"
                bg="#bfc9db"
            fi


        if [ $1 = "wifi" ]; then
            echo $icon
        elif [ $1 = "wifi_col"  ]; then
            echo $col
        elif [ $1 = "wifi_bg" ]; then
            echo $bg
        fi
      '')
      (writeShellScriptBin "workspace" ''
                workspaces() {
                  ws1="1"
                  ws2="2"
                  ws3="3"
                  ws4="4"
                  ws5="5"
                  ws6="6"

                  # Get all workspaces and their status
                  workspaces_json=$(hyprctl workspaces -j)
                  active_workspace=$(hyprctl activeworkspace -j | jq -r '.id')

                  # Check if occupied
                  o1=$(echo "$workspaces_json" | jq -e ".[] | select(.id == $ws1)" >/dev/null && echo "1" || echo "")
                  o2=$(echo "$workspaces_json" | jq -e ".[] | select(.id == $ws2)" >/dev/null && echo "1" || echo "")
                  o3=$(echo "$workspaces_json" | jq -e ".[] | select(.id == $ws3)" >/dev/null && echo "1" || echo "")
                  o4=$(echo "$workspaces_json" | jq -e ".[] | select(.id == $ws4)" >/dev/null && echo "1" || echo "")
                  o5=$(echo "$workspaces_json" | jq -e ".[] | select(.id == $ws5)" >/dev/null && echo "1" || echo "")
                  o6=$(echo "$workspaces_json" | jq -e ".[] | select(.id == $ws6)" >/dev/null && echo "1" || echo "")

                  # Check if focused
                  f1=$( [ "$active_workspace" = "$ws1" ] && echo "1" || echo "" )
                  f2=$( [ "$active_workspace" = "$ws2" ] && echo "1" || echo "" )
                  f3=$( [ "$active_workspace" = "$ws3" ] && echo "1" || echo "" )
                  f4=$( [ "$active_workspace" = "$ws4" ] && echo "1" || echo "" )
                  f5=$( [ "$active_workspace" = "$ws5" ] && echo "1" || echo "" )
                  f6=$( [ "$active_workspace" = "$ws6" ] && echo "1" || echo "" )

                  ic_1=""
                  ic_2=""
                  ic_3=""
                  ic_4=""
                  ic_5=""
                  ic_6=""

                  if [ "$f1" ]; then
                    ic_1=""
                  elif [ "$f2" ]; then
                    ic_2=""
                  elif [ "$f3" ]; then
                    ic_3=""
                  elif [ "$f4" ]; then
                    ic_4=""
                  elif [ "$f5" ]; then
                    ic_5=""
                  elif [ "$f6" ]; then
                    ic_6=""
                  fi

                un=0
                #          echo "(box :class 'works' :orientation 'h' :spacing 5 :space-evenly false
                #                (button :onclick 'hyprctl dispatch workspace $ws1' :class '$o1$f1' '$ic_1')
                #                (button :onclick 'hyprctl dispatch workspace $ws2' :class '$o2$f2' '$ic_2')
                #                (button :onclick 'hyprctl dispatch workspace $ws3' :class '$o3$f3' '$ic_3')
                #                (button :onclick 'hyprctl dispatch workspace $ws4' :class '$o4$f4' '$ic_4')
                #                (button :onclick 'hyprctl dispatch workspace $ws5' :class '$o5$f5' '$ic_5')
                #                (button :onclick 'hyprctl dispatch workspace $ws6' :class '$o6$f6' '$ic_6')
                #                )"
        echo 	"(box	:class \"works\"	:orientation \"h\" :spacing \"5\" :space-evenly \"false\" (button :onclick \"hyprctl dispatch workspace $ws1\"	:class	\"$un$o1$f1\"	\"$ic_1\") (button :onclick \"hyprctl dispatch workspace $ws2\"	:class \"$un$o2$f2\"	 \"$ic_2\") (button :onclick \"hyprctl dispatch workspace $ws3\"	:class \"$un$o3$f3\" \"$ic_3\") (button :onclick \"hyprctl dispatch workspace $ws4\"	:class \"$un$o4$f4\"	\"$ic_4\") (button :onclick \"hyprctl dispatch workspace $ws5\"	:class \"$un$o5$f5\" \"$ic_5\")  (button :onclick \"hyprctl dispatch workspace $ws6\"	:class \"$un$o6$f6\" \"$ic_6\"))"

                }

                workspaces

                # Listen for workspace changes
                # socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - |
                while read -r line; do
                  case $line in
                    *workspace*|*movewindow*|*movetoworkspace*)
                      workspaces
                      ;;
                  esac
                done
      '')
      # (writeShellScriptBin "workspace" ''
      #   #TODO, need to convert this into something else
      #   workspaces() {
      #   ws1="1"
      #   ws2="2"
      #   ws3="3"
      #   ws4="4"
      #   ws5="5"
      #   ws6="6"

      #   # Unoccupied
      #   un="0"

      #   # check if Occupied
      #   o1=$(bspc query -D -d .occupied --names | grep "$ws1" )
      #   o2=$(bspc query -D -d .occupied --names | grep "$ws2" )
      #   o3=$(bspc query -D -d .occupied --names | grep "$ws3" )
      #   o4=$(bspc query -D -d .occupied --names | grep "$ws4" )
      #   o5=$(bspc query -D -d .occupied --names | grep "$ws5" )
      #   o6=$(bspc query -D -d .occupied --names | grep "$ws6" )

      #   # check if Focused
      #   f1=$(bspc query -D -d focused --names | grep "$ws1" )
      #   f2=$(bspc query -D -d focused --names | grep "$ws2" )
      #   f3=$(bspc query -D -d focused --names | grep "$ws3" )
      #   f4=$(bspc query -D -d focused --names | grep "$ws4" )
      #   f5=$(bspc query -D -d focused --names | grep "$ws5" )
      #   f6=$(bspc query -D -d focused --names | grep "$ws6" )

      #   ic_1=""
      #   ic_2=""
      #   ic_3=""
      #   ic_4=""
      #   ic_5=""
      #   ic_6=""
      #   if [ $f1 ]; then
      #       ic_1=""
      #   elif [ $f2 ]; then
      #       ic_2=""
      #   elif [ $f3 ]; then
      #       ic_3=""
      #   elif [ $f4 ]; then
      #       ic_4=""
      #   elif [ $f5 ]; then
      #       ic_5=""
      #   elif [ $f6 ]; then
      #       ic_6=""
      #   fi

      #   echo 	"(box	:class \"works\"	:orientation \"h\" :spacing 5 :space-evenly \"false\" (button :onclick \"bspc desktop -f $ws1\"	:class	\"$un$o1$f1\"	\"$ic_1\") (button :onclick \"bspc desktop -f $ws2\"	:class \"$un$o2$f2\"	 \"$ic_2\") (button :onclick \"bspc desktop -f $ws3\"	:class \"$un$o3$f3\" \"$ic_3\") (button :onclick \"bspc desktop -f $ws4\"	:class \"$un$o4$f4\"	\"$ic_4\") (button :onclick \"bspc desktop -f $ws5\"	:class \"$un$o5$f5\" \"$ic_5\")  (button :onclick \"bspc desktop -f $ws6\"	:class \"$un$o6$f6\" \"$ic_6\"))"

      #   }
      #   workspaces
      #   bspc subscribe desktop node_transfer | while read -r _ ; do
      #   workspaces
      #   done
      # '')
      (writeShellScriptBin "getArtUrl" ''
        # Directory where album art images will be stored
        ART_DIR="/tmp/music_art"

        # Create the directory if it doesn't exist
        mkdir -p "$ART_DIR"

        # Function to clean up old files
        cleanup_old_files() {
            # Delete files older than 1 day
            find "$ART_DIR" -type f -mtime +1 -exec rm -f {} +
        }

        while IFS= read -r url; do
            if [ -n "$url" ]; then
                # Calculate the hash of the URL
                filename=$(echo -n "$url" | md5sum | cut -d ' ' -f1)
                localpath="$ART_DIR/$filename.jpg"  # Assuming JPEG format for simplicity
                # Download the image if it doesn't already exist
                if [ ! -f "$localpath" ]; then
                    ${pkgs.curl}/bin/curl -o "$localpath" "$url"
                fi
                echo "$localpath"
                # Clean up old files after fetching new one
                cleanup_old_files
            fi
        done < <(${pkgs.playerctl}/bin/playerctl --follow metadata --format '{{ mpris:artUrl }}' || true)
      '')
    ];
  services.dunst.enable = true;

  programs.eww.configDir = pkgs.stdenv.mkDerivation {
    src = ./.;
    name = "eww-config";
    installPhase = ''
      mkdir -p $out
      # cp #$ #{
      #   lib.my-lib.mustache.template {
      #     inherit pkgs;
      #     name = "eww-config-scss";
      #     templateFile = ./eww.scss.mustache;
      #     variables = {
      #       inherit (config.lib.stylix.colors) base00 base01 base02 base03 base04 base05 base06 base07 base08 base09 base0A base0B base0C base0D base0E base0F;
      #       desktopOpacity = builtins.toString config.stylix.opacity.desktop;
      #       font = config.stylix.fonts.sansSerif.name;
      #     };
      #   }
      # } $out/eww.scss
      cp bar/eww.scss  $out/
      cp bar/eww.yuck  $out/
      cp -r bar/images $out/
    '';
  };
}
