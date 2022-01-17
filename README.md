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
* Change Clock(1 Hz) is a pulse clock used in Delay finite state machine(FSM) 
	of **Core** module
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
This Core module contains the logic of the game. On start, some initialization
works is executed. For example, for given number of players, it sets the
11 sticks to remove in one-hot encoding of 11-bit register. Then, on Roll button
push, the main logic is executed. The whole logic can be represented in the 
following FSM:

![Delay FSM](/img/delay_fsm.png)

Delay FSM is 3-bit FSM, containing 8 distinct states. Four states of them
are for delaying 1 second of the game. Each stage spends one second, as 
the driving clock is Change clock(1 Hz). Technically, it is not a traditional
clock, which is toggle basis, but a pulse clock. Since the implementation checks
if the Change clock is high or not at 100 MHz rate, the traditional 1 Hz clock
would be 1/2 Hz clock in this implementation. For better readability, instead of 
having traditional 2 Hz clock, it takes 1 Hz pulse clock.

* S0
	* Animation: On roll button push, frequently-changing random numbers are
		displayed. It is also implemented with a FSM:
		
		![Animate FSM](/img/animate_fsm.png)

### Display Segment Module
This module determines the front-end of the game. Based on the processed data from
**Core** module, it outputs either alphabet letter or digit on four slots of 
seven-segment display.

![Seven Segments](/img/seven_seg.png)

* First segment indicates the game mode
    * `P` represents the Play mode, showing player is on turn (e.g. `P100`: Player 1 is ready to roll)
    * `S` represents the Score mode, followed by player number and the number of remaining
        sticks (e.g. `S109`: Player 1 has 9 sticks to remove) 
    * `E` represents the end of game, followed by a letter `G` and `Player#` (e.g. `EGP2`)
* Second segment mainly indicates the number of players in various modes
    * `1`~`4`: player number
    * `G`: End game mode
* Third segment
    * In Play mode, the value of first die(`1`~`6`)
    * In Score mode, ten's place of remaning sticks(`0`~`1`)
    * In End game mode, `P` as "Player"
* Fourth segment
    * In Play mode, the value of second die(`1`~`6`)
    * In Score mode, one's place of remaning sticks(`0`~`9`)
    * In End game mode, winning player number(`1`~`4`)
    
#### Mechanism: FSM
![Display FSM](/img/display_fsm.png)

With the `Fast Clock` of ~512 Hz, the above FSM is running. Each state outputs 
which segment is to draw in reverse one-hot encoding. More specifically, State 0 
outputs `0111`, which indicates the first segment is to draw, and so on. 