#!/bin/bash

# -------------------------------------------------- Variables section --------------------------------------------------

# Define pixel as 2 spaces
pixel="  "

# Get pong grid size, row height is 1 char and col width is 2 chars
declare -i grid_rows=$(($(tput lines)-5))
declare -i grid_cols=$((($(tput cols)-2)/2))

# Wheter game is running
declare -i game_running=0

# General paddle variables
declare -i paddle_height=10
declare -i paddle_width=1
declare -i paddle_speed=3

# Get paddles' start position
paddle_start_row=$(($grid_rows/2 - $paddle_height/2))

# Left paddle variables
declare -i left_paddle_row=$paddle_start_row
declare -i new_left_paddle_row=$left_paddle_row
declare -i left_paddle_col=0

# Right paddle variables
declare -i right_paddle_row=$paddle_start_row
declare -i new_right_paddle_row=$right_paddle_row
declare -i right_paddle_col=$(($grid_cols - 1))

# Ball variables
declare -i  ball_height=1
declare -i  ball_width=1
declare -i  ball_row=$(($grid_rows/2 - 2))
declare -i  ball_col=$(($grid_cols/2))
declare -i  ball_step_x=-1
declare -i  ball_step_y=1

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
    for ((i=0; i<grid_rows; i++)); do
        for ((j=0; j<grid_cols; j++)); do
            eval "arr$i[$j]=\"$pixel\""
        done
    done
}


move_and_draw() {
    printf "\e[${1};${2}H$3"
}


draw_rectangle()
{
    local height=$5
    local width=$6

    for ((i=0; i<$height; i++)); do
        for ((j=0; j<$width; j++)); do
            eval "arr$(($1+$i))[$(($2+$j))]=\"${3}$pixel${4}\""
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
    if [ "$pos" == "$border_color$pixel$no_color" ]; then
        return 0
    fi

    return 1
}


draw_grid()
{
    # Top row
    move_and_draw 1 1 "$border_color+$no_color"
    for ((i=1; i<=grid_cols; i++)); do
        move_and_draw 1 $(($i*2)) "$border_color--$no_color"
    done
    move_and_draw 1 $((grid_cols*2 + 2)) "$border_color+$no_color"

    # Middle rows
    for ((i=0; i<grid_rows; i++)); do
        move_and_draw $((i+2)) 1 "$border_color|$no_color"
        eval printf "\"\${arr$i[*]}\""
        printf "$border_color|$no_color"
    done

    # Bottom row
    move_and_draw $((grid_rows+2)) 1 "$border_color+$no_color"
    for ((i=1; i<=grid_cols; i++)); do
        move_and_draw $((grid_rows+2)) $(($i*2)) "$border_color--$no_color"
    done
    move_and_draw $((grid_rows+2)) $((grid_cols*2 + 2)) "$border_color+$no_color"
}


move_left_paddle()
{
    if [ $(($1 + $2)) -ge 0 ] && [ $(($1 + $2 + $paddle_height)) -le $grid_rows ]; then
        new_left_paddle_row=$(($1 + $2))
    elif [ $2 -lt 0 ]; then
        new_left_paddle_row=0
    else
        new_left_paddle_row=$(($grid_rows - $paddle_height))
    fi
}


move_right_paddle()
{
    if [ $(($1 + $2)) -ge 0 ] && [ $(($1 + $2 + $paddle_height)) -le $grid_rows ]; then
        new_right_paddle_row=$(($1 + $2))
    elif [ $2 -lt 0 ]; then
        new_right_paddle_row=0
    else
        new_right_paddle_row=$(($grid_rows - $paddle_height))
    fi
}


move_paddles()
{
    # Left paddle
    draw_paddle "$left_paddle_row" "$left_paddle_col" "$no_color" "$no_color"
    left_paddle_row=$new_left_paddle_row
    draw_paddle "$left_paddle_row" "$left_paddle_col" "$border_color" "$no_color"

    # Right paddle
    draw_paddle "$right_paddle_row" "$right_paddle_col" "$no_color" "$no_color"
    right_paddle_row=$new_right_paddle_row
    draw_paddle "$right_paddle_row" "$right_paddle_col" "$border_color" "$no_color"
}


move_ball()
{
    local next_ball_row=$(($ball_row + $ball_step_x))
    local next_ball_col=$(($ball_col + $ball_step_y))

    # Check bounce from top or bottom
    if [ $next_ball_row -lt 0 ] || [ $next_ball_row -ge "$grid_rows" ]; then
        ball_step_x=$(($ball_step_x*-1))
        next_ball_row=$(($ball_row + $ball_step_x))
    fi

    # Check if ball went out of bounds or bounced of the paddles
    if [ $next_ball_col -lt 0 ] || [ $next_ball_col -ge "$grid_cols" ]; then
        game_running=0
    elif $(detect_ball_x_paddle_colision $next_ball_row $next_ball_col); then
        ball_step_y=$(($ball_step_y*-1))
        next_ball_col=$(($ball_col + $ball_step_y))
    fi

    # If bounced, clear old position, move and redraw
    if [ $game_running -eq 1 ]; then
        draw_ball "$ball_row" "$ball_col" "$no_color" "$no_color"
        ball_row=$next_ball_row
        ball_col=$next_ball_col
        draw_ball "$ball_row" "$ball_col" "$ball_color" "$no_color"
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
            'o')    kill -$SIG_RIGHT_UP $game_pid   # o
                    ;;
            'l')    kill -$SIG_RIGHT_DOWN $game_pid # l
                    ;; 
        esac
    done
}

draw_start_message()
{
    local mid_row=$(($grid_rows / 2))
    local mid_col=$(($grid_cols / 2))
    declare -i str_col

    eval "str_arr0=(-11 -10 -9 -8 -6 -3 -1 0 1 3 4 5 6 8 9 10)"
    eval "str_arr1=(-11 -6 -5 -3 0 3 8 11)"
    eval "str_arr2=(-11 -10 -9 -6 -4 -3 0 3 4 5 8 9 10)"
    eval "str_arr3=(-11 -6 -3 0 3 8 11)"
    eval "str_arr4=(-11 -10 -9 -8 -6 -3 0 3 4 5 6 8 11)"
    eval "str_arr5=()"
    eval "str_arr6=(-3 -2 -1 2 3)"
    eval "str_arr7=(-2 1 4)"
    eval "str_arr8=(-2 1 4)"
    eval "str_arr9=(-2 1 4)"
    eval "str_arr10=(-2 2 3)"
    eval "str_arr11=()"
    eval "str_arr12=(-8 -9 -10 -6 -5 -4 -1 0 3 4 5 8 9 10)"
    eval "str_arr13=(-11 -5 -2 1 3 6 9)"
    eval "str_arr14=(-9 -10 -5 -2 -1 0 1 3 4 5 9)"
    eval "str_arr15=(-8 -5 -2 1 3 6 9)"
    eval "str_arr16=(-9 -10 -11 -5 -2 1 3 6 9)"

    for ((i=0; i<=16; i++)); do
        eval "sub_arr_len=\${#str_arr$i[@]}"
        for ((j=0; j<sub_arr_len; j++)); do
            eval "str_col=\$((str_arr$i[$j]))";
            eval "arr$(($mid_row+$i-8))[$(($mid_col+$str_col))]=\"\$1\$pixel\$no_color\"";
        done
    done
    
    draw_grid
}

start_screen_loop()
{
    local message_color
    declare -i counter=0

    while [ $counter -le 4 ];
    do
        if (( $counter % 2 == 0 )); then
            message_color=$border_color
        else
            message_color=$no_color
        fi

        counter=$(($counter+1))
        draw_start_message "$message_color"
        sleep 0.45
    done
    

    while true;
    do
        read -rsn1 input # get 1 char
        if [[ $input = "" ]]; then 
            break
        fi
    done

    draw_start_message "$no_color"
    game_running=1
    sleep 0.5
}

game_loop()
{
    trap "move_left_paddle   \$left_paddle_row  -\$paddle_speed"    $SIG_LEFT_UP
    trap "move_left_paddle   \$left_paddle_row  \$paddle_speed"     $SIG_LEFT_DOWN
    trap "move_right_paddle  \$right_paddle_row -\$paddle_speed"    $SIG_RIGHT_UP
    trap "move_right_paddle  \$right_paddle_row \$paddle_speed"     $SIG_RIGHT_DOWN
    trap "exit 1;"                                                  $SIG_QUIT

    while [ $game_running -eq 1 ];
    do
        move_paddles
        move_ball
        draw_grid
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
draw_grid

start_screen_loop
game_loop & game_pid=$!
get_user_input

clear_game
exit 0
