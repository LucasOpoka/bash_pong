#!/bin/bash

# -------------------------------------------------- Variables section --------------------------------------------------

# Wheter game is running
declare -i still_running=1

# Get pong grid size
declare -i height=$(($(tput lines)-5))
declare -i width=$(($(tput cols)-2))

# Ensure width is even since both ball's width and horizontal step are 2
if (( width % 2 == 1 )); then
width=$(($width-1))
fi

# Ensure height is even since paddle's width is even and vertical step is 2
if (( height % 2 == 1 )); then
height=$(($height-1))
fi

# General paddle variables
paddle_height=10
paddle_width=2
paddle_step=2

# Get paddles' start position
paddle_start_x=$(($height/2 - $paddle_height/2))
if (( paddle_start_x % 2 == 1 )); then
    paddle_start_x=$(($paddle_start_x-1))
fi

# Left paddle variables
declare -i paddle_x1=$paddle_start_x
declare -i new_paddle_x1=$paddle_x1
declare -i paddle_y1=0

# Right paddle variables
declare -i paddle_x2=$paddle_start_x
declare -i new_paddle_x2=$paddle_x2
declare -i paddle_y2=$(($width - 2))

# Ball variables
declare -i  ball_height=1
declare -i  ball_width=2
declare -i  ball_x=$(($height/2 - 2))
declare -i  ball_y=$(($width/2))
declare -i  ball_step_x=-1
declare -i  ball_step_y=2

# Ensure starting ball col is even
if (( ball_y % 2 == 1 )); then
ball_y=$(($ball_y-1))
fi

# Internal field separator, how bash splits strings
IFS=''

# Colors variables
ball_color="\e[46m"
border_color="\e[102m"
no_color="\e[0m"

# Signals
SIG_LEFT_UP=USR1
SIG_LEFT_DOWN=USR2
SIG_RIGHT_UP=URG
SIG_RIGHT_DOWN=IO
SIG_QUIT=WINCH
SIG_END=HUP


# -------------------------------------------------- Functions section --------------------------------------------------
init_game() {
    clear
    printf "\e[?25l"
    stty -echo
    for ((i=0; i<height; i++)); do
        for ((j=0; j<width; j++)); do
            eval "arr$i[$j]=' '"
        done
    done
}


move_and_draw() {
    printf "\e[${1};${2}H$3"
}


draw_rectangle()
{
    for ((i=0; i<$5; i++)); do
        for ((j=0; j<$6; j++)); do
            eval "arr$(($1+$i))[$(($2+$j))]=\"${3} ${4}\""
        done
    done
}


draw_paddle()
{
    draw_rectangle "$1" "$2" "$3" "$4" "$paddle_height" "$paddle_width"
}


draw_ball()
{
    draw_rectangle "$1" "$2" "$3" "$4" "$ball_height" "$ball_width"
}


detect_ball_x_paddle_colision()
{
    local position;

    eval "pos=\${arr$(($1))[$(($2))]}"
    if [ "$pos" == "$border_color $no_color" ]; then
        return 0
    fi

    return 1
}


draw_board() {
    move_and_draw 1 1 "$border_color+$no_color"
    for ((i=2; i<=width+1; i++)); do
        move_and_draw 1 $i "$border_color-$no_color"
    done
    move_and_draw 1 $((width + 2)) "$border_color+$no_color"

    for ((i=0; i<height; i++)); do
        move_and_draw $((i+2)) 1 "$border_color|$no_color"
        eval printf "\"\${arr$i[*]}\""
        printf "$border_color|$no_color"
    done

    move_and_draw $((height+2)) 1 "$border_color+$no_color"
    for ((i=2; i<=width+1; i++)); do
        move_and_draw $((height+2)) $i "$border_color-$no_color"
    done
    move_and_draw $((height+2)) $((width + 2)) "$border_color+$no_color"
}


move_left_paddle_height()
{
    if [ $(($1 + $2)) -ge 0 ] && [ $(($1 + $paddle_height + $2)) -le $height ]; then
        new_paddle_x1=$(($1 + $2))
    else
        new_paddle_x1=$1
    fi
}


move_right_paddle_height()
{
    if [ $(($1 + $2)) -ge 0 ] && [ $(($1 + $paddle_height + $2)) -le $height ]; then
        new_paddle_x2=$(($1 + $2))
    else
        new_paddle_x2=$1
    fi
}


move_paddles() {
    # Left paddle
    draw_paddle "$paddle_x1" "$paddle_y1" "$no_color" "$no_color"
    paddle_x1=$new_paddle_x1
    draw_paddle "$paddle_x1" "$paddle_y1" "$border_color" "$no_color"

    # Right paddle
    draw_paddle "$paddle_x2" "$paddle_y2" "$no_color" "$no_color"
    paddle_x2=$new_paddle_x2
    draw_paddle "$paddle_x2" "$paddle_y2" "$border_color" "$no_color"
}


move_ball()
{
    local next_ball_x=$(($ball_x + $ball_step_x))
    local next_ball_y=$(($ball_y + $ball_step_y))


    # Clear old position
    draw_ball "$ball_x" "$ball_y" "$no_color" "$no_color"

    # Check bounce from top or bottom
    if [ $next_ball_x -lt 0 ] || [ $next_ball_x -ge "$height" ]; then
        ball_step_x=$(($ball_step_x*-1))
        next_ball_x=$(($ball_x + $ball_step_x))
    fi

    # Check if ball went out of bounds or bounced of the paddles
    if [ $next_ball_y -lt 0 ] || [ $next_ball_y -ge "$width" ]; then
        still_running=0
    elif $(detect_ball_x_paddle_colision $next_ball_x $next_ball_y); then
        ball_step_y=$(($ball_step_y*-1))
        next_ball_y=$(($ball_y + $ball_step_y))
    fi

    # If bounced move and redraw
    if [ $still_running -eq 1 ]; then
        ball_x=$next_ball_x
        ball_y=$next_ball_y
        draw_ball "$ball_x" "$ball_y" "$ball_color" "$no_color"
    fi
}


get_user_input()
{
    trap "" SIGINT SIGQUIT
    trap "return;" $SIG_END

    while true;
    do
        read -rsn1 input # get 1 char

        case $input in
            'q')    kill -$SIG_QUIT $game_pid
                    return
                    ;;
            'w')    kill -$SIG_LEFT_UP $game_pid    # w
                    ;;
            's')    kill -$SIG_LEFT_DOWN $game_pid  # s
                    ;;
            'o')   kill -$SIG_RIGHT_UP $game_pid    # o
                    ;;
            'l')   kill -$SIG_RIGHT_DOWN $game_pid  # l
                    ;; 
        esac
    done
}


game_loop()
{
    trap "move_left_paddle_height \$paddle_x1 -\$paddle_step"  $SIG_LEFT_UP
    trap "move_left_paddle_height \$paddle_x1 \$paddle_step"   $SIG_LEFT_DOWN
    trap "move_right_paddle_height \$paddle_x2 -\$paddle_step" $SIG_RIGHT_UP
    trap "move_right_paddle_height \$paddle_x2 \$paddle_step"  $SIG_RIGHT_DOWN
    trap "exit 1;"                                              $SIG_QUIT

    while [ $still_running -eq 1 ];
    do
        move_paddles
        move_ball
        draw_board
        sleep 0.05
    done

    # Signal to kill the input loop
    kill -$SIG_END $$
}


clear_game()
{
    stty echo
    printf "\e[?25h"
}


# -------------------------------------------------- Main section --------------------------------------------------

init_game
draw_board

game_loop & game_pid=$!
get_user_input

clear_game
exit 0
