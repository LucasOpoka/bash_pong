#!/bin/bash

# -------------------------------------------------- Variables section --------------------------------------------------

# Wheter game is running
declare -i still_running=1

# Get pong grid size
declare -i grid_rows=$(($(tput lines)-5))
declare -i grid_cols=$(($(tput cols)-2))

# Ensure grid_cols is even since both ball's width and horizontal step are 2
if (( grid_cols % 2 == 1 )); then
grid_cols=$(($grid_cols-1))
fi

# Ensure grid_rows is even since paddle's height is even and vertical step is 2
if (( grid_rows % 2 == 1 )); then
grid_rows=$(($grid_rows-1))
fi

# General paddle variables
declare -i paddle_height=10
declare -i paddle_width=2
declare -i paddle_step=2
declare -i paddle_speed=2

# Get paddles' start position
paddle_start_row=$(($grid_rows/2 - $paddle_height/2))
if (( paddle_start_row % 2 == 1 )); then
    paddle_start_row=$(($paddle_start_row-1))
fi

# Left paddle variables
declare -i left_paddle_row=$paddle_start_row
declare -i new_left_paddle_row=$left_paddle_row
declare -i left_paddle_col=0

# Right paddle variables
declare -i right_paddle_row=$paddle_start_row
declare -i new_right_paddle_row=$right_paddle_row
declare -i right_paddle_col=$(($grid_cols - 2))

# Ball variables
declare -i  ball_height=1
declare -i  ball_width=2
declare -i  ball_row=$(($grid_rows/2 - 2))
declare -i  ball_col=$(($grid_cols/2))
declare -i  ball_step_x=-1
declare -i  ball_step_y=2

# Ensure starting ball col is even
if (( ball_col % 2 == 1 )); then
ball_col=$(($ball_col-1))
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
    for ((i=0; i<grid_rows; i++)); do
        for ((j=0; j<grid_cols; j++)); do
            eval "arr$i[$j]=' '"
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
    for ((i=2; i<=grid_cols+1; i++)); do
        move_and_draw 1 $i "$border_color-$no_color"
    done
    move_and_draw 1 $((grid_cols + 2)) "$border_color+$no_color"

    for ((i=0; i<grid_rows; i++)); do
        move_and_draw $((i+2)) 1 "$border_color|$no_color"
        eval printf "\"\${arr$i[*]}\""
        printf "$border_color|$no_color"
    done

    move_and_draw $((grid_rows+2)) 1 "$border_color+$no_color"
    for ((i=2; i<=grid_cols+1; i++)); do
        move_and_draw $((grid_rows+2)) $i "$border_color-$no_color"
    done
    move_and_draw $((grid_rows+2)) $((grid_cols + 2)) "$border_color+$no_color"
}


move_left_paddle()
{
    new_left_paddle_row=$1
    for ((i=0; i<$3; i++)); do
        if [ $(($new_left_paddle_row + $2)) -ge 0 ] && [ $(($new_left_paddle_row + $paddle_height + $2)) -le $grid_rows ]; then
            new_left_paddle_row=$(($new_left_paddle_row + $2))
        else
            break
        fi
    done
}


move_right_paddle()
{
    new_right_paddle_row=$1
    for ((i=0; i<$3; i++)); do
        if [ $(($new_right_paddle_row + $2)) -ge 0 ] && [ $(($new_right_paddle_row + $paddle_height + $2)) -le $grid_rows ]; then
            new_right_paddle_row=$(($new_right_paddle_row + $2))
        else
            break
        fi
    done
}


move_paddles() {
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


    # Clear old position
    draw_ball "$ball_row" "$ball_col" "$no_color" "$no_color"

    # Check bounce from top or bottom
    if [ $next_ball_row -lt 0 ] || [ $next_ball_row -ge "$grid_rows" ]; then
        ball_step_x=$(($ball_step_x*-1))
        next_ball_row=$(($ball_row + $ball_step_x))
    fi

    # Check if ball went out of bounds or bounced of the paddles
    if [ $next_ball_col -lt 0 ] || [ $next_ball_col -ge "$grid_cols" ]; then
        still_running=0
    elif $(detect_ball_x_paddle_colision $next_ball_row $next_ball_col); then
        ball_step_y=$(($ball_step_y*-1))
        next_ball_col=$(($ball_col + $ball_step_y))
    fi

    # If bounced move and redraw
    if [ $still_running -eq 1 ]; then
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
            'o')   kill -$SIG_RIGHT_UP $game_pid    # o
                    ;;
            'l')   kill -$SIG_RIGHT_DOWN $game_pid  # l
                    ;; 
        esac
    done
}


game_loop()
{
    trap "move_left_paddle   \$left_paddle_row -\$paddle_step  \$paddle_speed" $SIG_LEFT_UP
    trap "move_left_paddle   \$left_paddle_row \$paddle_step   \$paddle_speed" $SIG_LEFT_DOWN
    trap "move_right_paddle  \$right_paddle_row -\$paddle_step  \$paddle_speed" $SIG_RIGHT_UP
    trap "move_right_paddle  \$right_paddle_row \$paddle_step   \$paddle_speed" $SIG_RIGHT_DOWN
    trap "exit 1;"                                                              $SIG_QUIT

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
