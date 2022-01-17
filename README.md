# FPGA board game: Boxed
###### CS M152A: Introductory Digital Design Laboratory, Spring 2018

**Boxed** is a game of two dice for two or more players. Initially, each
player has 11 sticks to eliminate; sticks are labeled from 2 to 12. On turn,
player rolls the dice and eliminates the stick of sum of value of rolled dice.
The player who first removes all sticks win the game.

The game, Boxed, is simulated on FPGA board with Verilog.

## High-level Design
![High-level Design](/img/structure.png)

### Clock Divider
This module divides the master clock(100 MHz) into the following clocks required
in various sub-modules:
* Fast Clock(~512 Hz) is used as a driver clock in **Display Segment** module
* Change Clock(1 Hz) is used in Delay finite state machine(FSM) of **Core** module
* Flash Clock(5 Hz) is used for flashing effect of display when the game is over
    in **Core** module
* New Clock(5 Hz) is used as a driver clock of Animate FSM in **Core** module


### Async Button Handler
This handler is a debouncer of `Start` and `Roll` hardware button. Due to
the nature of mechanical buttons, when it is pressed, it won't 
make immediate contact but will shift around a little bit. More specifically,
the input signal bounces up and down for a short slit of time. Therefore, the
debouncer is required, ignoring the bouncing of signal.
```
assign out = push_ff[0];

always @ (posedge clk or posedge btn_push) begin
   if (btn_push) push_ff <= 2'b11;
   else          push_ff <= {1'b0, push_ff[1]};
end
```
In order to simulate the bouncer, SR flip-flop latch is used. For the latch by 
remembering one previous status of input, the bouncing is ignored. Depending on
the clock speed, the latch could be re-sized for better reliability.

| BUTTON | Flip-flop | OUTPUT |
|:------:|:---------:|:------:|
| 1      | 11        | 1      |
| 0      | 01        | 1      |
| 1      | 11        | 1      |
| 0      | 01        | 1      |
| 0      | 00        | 0      |

### Core

### Display Segment Module
This module determines the front-end of the game. Based on the processed data from
**Core** module, it outputs either alphabet letter or digit on four slots of 
seven-segment display.
#### Mechanism: FSM
![Display FSM](/img/display_fsm.png)
