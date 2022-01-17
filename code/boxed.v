module boxed (
    //inputs
    clk, btn_start, btn_roll, sw_score, sw_players,
    //outputs
    seg, an
);

input clk, btn_start, btn_roll, sw_score;
input [1:0] sw_players;

output [3:0] an;
output [7:0] seg;

wire fast_clk; //iterate through display
wire change_clk; //1HZ before sum is display & on win
wire flash_clk; //flash 5HZ
wire new_clk; //flash 5HZ

wire [3:0] ones_place;  //0-9 digits
wire [3:0] tens_place; //0-9 digits
wire [2:0] player_num_place; //1-4 players + G
wire [1:0] p_disp; //display P

//START BUTTON
wire astrt_i;
wire strt;
reg [1:0] astrt_ff;

assign astrt_i = btn_start;
assign strt = astrt_ff[0];

always @ (posedge clk or posedge astrt_i) begin
   if (astrt_i)
     astrt_ff <= 2'b11;
   else
     astrt_ff <= {1'b0, astrt_ff[1]};
end

//ROLL BUTTON
wire arll_i;
wire rll;
reg [1:0] arll_ff;

assign arll_i = btn_roll;
assign rll = arll_ff[0];

always @ (posedge clk or posedge arll_i) begin
   if (arll_i)
     arll_ff <= 2'b11;
   else
     arll_ff <= {1'b0, arll_ff[1]};
end

clock_divider clock_divider_(
  // input
	.master_clk(clk),
  // outputs
	.fast_clk(fast_clk),
	.change_clk(change_clk),
	.flash_clk(flash_clk),
	.new_clk(new_clk)
);

core core_ (
	// inputs
	.start(strt),
	.roll(rll),
	.score_mode(sw_score),
	.clk(clk),
	.change_clock(change_clk),
	.flash_clock(flash_clk),
	.new_clock(new_clk),
	.number_of_player(sw_players),
	// outputs
	.ones_place(ones_place),
	.tens_place(tens_place),
	.player_num_place(player_num_place),
	.p_disp(p_disp)
);

display_seg display_seg_(
  // inputs
	.change_clk(change_clk),
	.fast_clk(fast_clk),
	.ones_place(ones_place),
	.tens_place(tens_place),
	.number_of_players(sw_players),
	.player_num_place(player_num_place),
	.p_disp(p_disp),
	.score_mode(sw_score),
  // outputs
	.seg(seg),
	.an(an)
);

endmodule


/********/
/* CORE */
/********/
module core(
	//inputs
	start, roll, score_mode, clk, number_of_player, change_clock, 
		flash_clock, new_clock,
	//outputs
	ones_place, tens_place, player_num_place, p_disp, an
);

input start, roll, score_mode, clk, change_clock, flash_clock, new_clock;

input [1:0] number_of_player; //0 is four players, 1 = 1 player, 2 = 2 players, etc.

output reg [3:0] ones_place;
output reg [3:0] tens_place;
output reg [1:0] p_disp;
output reg [2:0] player_num_place;
output reg [3:0] an;

reg [1:0] num_players_on_start;

reg [10:0] player_1_box;
reg [10:0] player_2_box;
reg [10:0] player_3_box;
reg [10:0] player_4_box;
reg [3:0] player_1_box_left;
reg [3:0] player_2_box_left;
reg [3:0] player_3_box_left;
reg [3:0] player_4_box_left;

reg [2:0] tens_die;
reg [2:0] ones_die;
reg [3:0] sum_of_dice;

reg [1:0] player_turn_counter;
reg [2:0] delay_fsm = 0;

reg rollPressed = 0;

reg [2:0] random1; //0-7
reg [2:0] random2 = 7; //0-7

reg [2:0] randOkayCounter = 0;
reg [3:0] randOkay = 0;

always@(posedge clk)
begin
   if(random1 < 6)	random1 <= random1 + 1;
   else					random1 <= 1;
   if(random2 > 0)	random2 <= random2 - 1;
   else					random2 <= 6;

   if(1)// !score_mode
     begin
	p_disp <= 0;
	//On Start Initialize & Check That You Are Not Starting with One Player
	if(start)
	  begin
	     //Clear and Reset Display
	     ones_place <= 0;
	     tens_place <= 0;
	     p_disp <= 0; //Set P
	     player_num_place <= 1; //Set to First Player
	     
	     //initialize boxes to one (unhit and in the box)
	     player_1_box <= 11'b11111111111;
	     player_2_box <= 11'b11111111111;
	     player_3_box <= 11'b11111111111;
	     player_4_box <= 11'b11111111111;
	     
	     //Initialize to first player
	     player_turn_counter = 0;
	     
	     //Store Number of Players
	     num_players_on_start <= number_of_player;
	     
	     rollPressed <= 0;
	     delay_fsm = 0;
	  end
	else
	  begin
	     case(num_players_on_start)
	       1: //Display Error if Started with One Player
		 begin
		    p_disp <= 2;
		    player_num_place <= 6;
		    tens_place <= 9;
		    ones_place <= 11;
		 end
	       2: //Two Players
		 begin
		    case(player_turn_counter)
		      0: //First Player Turn
			begin
			   player_num_place <= 1;
			   player_1_box_left = player_1_box[0] + player_1_box[1] + player_1_box[2] + player_1_box[3] + player_1_box[4] + player_1_box[5] +
					       | player_1_box[6] + player_1_box[7] + player_1_box[8]  + player_1_box[9] + player_1_box[10];
			   
			   if(score_mode && !rollPressed)
			     begin
				p_disp <= 1;
				case(player_1_box_left) // display sum in tens_place and ones_place
				  1:
				    begin
				       tens_place <= 0;
				       ones_place <= 1;
				    end
				  2:
				    begin
				       tens_place <= 0;
				       ones_place <= 2;
				    end
				  3:
				    begin
				       tens_place <= 0;
				       ones_place <= 3;
				    end
				  4:
				    begin
				       tens_place <= 0;
				       ones_place <= 4;
				    end
				  5:
				    begin
				       tens_place <= 0;
				       ones_place <= 5;
				    end
				  6:
				    begin
				       tens_place <= 0;
				       ones_place <= 6;
				    end
				  7:
				    begin
				       tens_place <= 0;
				       ones_place <= 7;
				    end
				  8:
				    begin
				       tens_place <= 0;
				       ones_place <= 8;
				    end
				  9:
				    begin
				       tens_place <= 0;
				       ones_place <= 9;
				    end
				  10:
				    begin
				       tens_place <= 1;
				       ones_place <= 0;
				    end
				  11:
				    begin
				       tens_place <= 1;
				       ones_place <= 1;
				    end
				endcase
			     end
			   else
			     begin
				if(!rollPressed)
				  begin
				     tens_place <= 0;
				     ones_place <= 0;
				  end
				p_disp <= 0;
				
				//Check if the Roll Button is Pressed and initial state
				if(roll)
				  begin
				     rollPressed <= 1;
				     randOkayCounter <= 0;
				     randOkay = 0;
				  end
				
				if(rollPressed)
				  begin
				     case(delay_fsm)
				       0:
					 begin
    					    if(randOkay < 5)
    					      begin
    						 case (randOkayCounter)
    						   0:
    						     begin
    							ones_place <= 1;
    							tens_place <= 1;
    							if(new_clock)
    							  randOkayCounter <= 1;
    						     end
    						   1:
    						     begin
    							ones_place <= 2;
    							tens_place <= 2;
    							if(new_clock)
    							  randOkayCounter <= 2;
    						     end
    						   2:
    						     begin
    							ones_place <= 3;
    							tens_place <= 3;
    							if(new_clock)
    							  randOkayCounter <= 3;
    						     end
    						   3:
    						     begin
    							ones_place <= 4;
    							tens_place <= 4;
    							if(new_clock)
    							  randOkayCounter <= 4;
    						     end
    						   4:
    						     begin
    							ones_place <= 5;
    							tens_place <= 5;
    							if(new_clock)
    							  randOkayCounter <= 5;
    						     end
    						   5:
    						     begin
    							ones_place <= 6;
    							tens_place <= 6;
    							if(new_clock)
    							  begin
    							     randOkayCounter <= 0;
    							     randOkay = randOkay + 1;
    							  end
    						     end
    						 endcase
    					      end
    					    else
    					      begin
						 case(random1)
						   1: tens_die <= 1;
						   2: tens_die <= 2;
						   3: tens_die <= 3;
						   4: tens_die <= 4;
						   5: tens_die <= 5;
						   6: tens_die <= 6;
    						   7: tens_die <= 6;
						 endcase
    						 tens_place <= tens_die;
    						 //Set Display to the Generated Values
						 
						 case(random2)
						   0: ones_die <= 1;
        					   1: ones_die <= 1;
						   2: ones_die <= 2;
						   3: ones_die <= 3;
						   4: ones_die <= 4;
						   5: ones_die <= 5;
						   6: ones_die <= 6;
        					   7: ones_die <= 6;
						 endcase
						 ones_place <= ones_die;
						 
        					 //Store the sum of both dice
        					 sum_of_dice <= tens_die + ones_die;
        					 if(change_clock)
        					   delay_fsm = 1;
        				      end
					 end
				       1:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 2;
					      end
					 end
				       2:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 3;
					      end
					 end
				       3:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 3; //Set to blank
						 player_num_place <= 5; //Set to blank
						 tens_place <= 8; //Set to blank
						 ones_place <= 10; //Set to blank
						 delay_fsm = 4;
					      end
					 end
				       4:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 0; //Set to P
						 player_num_place <= 1; //Set to Player 1
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment Start
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //Remove from the First Player's Box the Value at the Index - 1
						 player_1_box[sum_of_dice - 2] <= 0;
						 
						 case(sum_of_dice) // display sum in tens_place and ones_place
						   2:
						     begin
							tens_place <= 0;
							ones_place <= 2;
						     end
						   3:
						     begin
							tens_place <= 0;
							ones_place <= 3;
						     end
						   4:
						     begin
							tens_place <= 0;
							ones_place <= 4;
						     end
						   5:
						     begin
							tens_place <= 0;
							ones_place <= 5;
						     end
						   6:
						     begin
							tens_place <= 0;
							ones_place <= 6;
						     end
						   7:
						     begin
							tens_place <= 0;
							ones_place <= 7;
						     end
						   8:
						     begin
							tens_place <= 0;
							ones_place <= 8;
						     end
						   9:
						     begin
							tens_place <= 0;
							ones_place <= 9;
						     end
						   10:
						     begin
							tens_place <= 1;
							ones_place <= 0;
						     end
						   11:
						     begin
							tens_place <= 1;
							ones_place <= 1;
						     end
						   12:
						     begin
							tens_place <= 1;
							ones_place <= 2;
						     end
						 endcase
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment End
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 delay_fsm = 5;
					      end
					 end
				       5:
					 begin
					    if(change_clock)
					      delay_fsm = 6;
					 end
				       6:
					 begin
					    if(change_clock)
					      delay_fsm = 7;
					 end
				       7:
					 begin
					    //check if the player hasn't won
					    if(player_1_box_left != 0)
					      begin
						 rollPressed <= 0;
						 tens_place <= 0;
						 ones_place <= 0;
						 player_turn_counter = 1;
						 delay_fsm = 0;
					      end
					    else
					      begin
						 //set display to End Game Mode
						 //EG P1
						 //Constantly Flash in and out
						 if(flash_clock)
						   begin
						      p_disp <= 2;//Set to E
						      player_num_place <= 0; //Set to G
						      tens_place <= 7; //Set to P
						      ones_place <= 1; //Set to 1
						   end
						 else
						   begin
						      p_disp <= 3;//Set to blank
						      player_num_place <= 5; //Set to blank
						      tens_place <= 8; //Set to blank
						      ones_place <= 10; //Set to blank
						   end
					      end
					 end
				     endcase
				  end
			     end
			end
		      1: //Second Player Turn
			begin
			   
			   player_num_place <= 2;
			   player_2_box_left = player_2_box[0] + player_2_box[1] + player_2_box[2] + player_2_box[3] + player_2_box[4] + player_2_box[5] + 
					       | player_2_box[6] + player_2_box[7] + player_2_box[8]  + player_2_box[9] + player_2_box[10];
			   //Check if the Roll Button is Pressed and initial state
			   if(score_mode && !rollPressed)
			     begin
				p_disp <= 1;
				case(player_2_box_left) // display sum in tens_place and ones_place
				  1:
				    begin
				       tens_place <= 0;
				       ones_place <= 1;
				    end
				  2:
				    begin
				       tens_place <= 0;
				       ones_place <= 2;
				    end
				  3:
				    begin
				       tens_place <= 0;
				       ones_place <= 3;
				    end
				  4:
				    begin
				       tens_place <= 0;
				       ones_place <= 4;
				    end
				  5:
				    begin
				       tens_place <= 0;
				       ones_place <= 5;
				    end
				  6:
				    begin
				       tens_place <= 0;
				       ones_place <= 6;
				    end
				  7:
				    begin
				       tens_place <= 0;
				       ones_place <= 7;
				    end
				  8:
				    begin
				       tens_place <= 0;
				       ones_place <= 8;
				    end
				  9:
				    begin
				       tens_place <= 0;
				       ones_place <= 9;
				    end
				  10:
				    begin
				       tens_place <= 1;
				       ones_place <= 0;
				    end
				  11:
				    begin
				       tens_place <= 1;
				       ones_place <= 1;
				    end
				endcase
			     end
			   else
			     begin
				if(!rollPressed)
				  begin
				     tens_place <= 0;
				     ones_place <= 0;
				  end
				p_disp <= 0;
  				if(roll)
  				  begin
  				     rollPressed <= 1;
  				     randOkayCounter <= 0;
  				     randOkay = 0;
  				  end
  				if(rollPressed)
  				  begin
				     case(delay_fsm)
				       0:
					 begin
					    if(randOkay < 5)
					      begin
						 case (randOkayCounter)
						   0:
						     begin
							ones_place <= 1;
							tens_place <= 1;
							if(new_clock)
							  randOkayCounter <= 1;
						     end
						   1:
						     begin
							ones_place <= 2;
							tens_place <= 2;
							if(new_clock)
							  randOkayCounter <= 2;
						     end
						   2:
						     begin
							ones_place <= 3;
							tens_place <= 3;
							if(new_clock)
							  randOkayCounter <= 3;
						     end
						   3:
						     begin
							ones_place <= 4;
							tens_place <= 4;
							if(new_clock)
							  randOkayCounter <= 4;
						     end
						   4:
						     begin
							ones_place <= 5;
							tens_place <= 5;
							if(new_clock)
							  randOkayCounter <= 5;
						     end
						   5:
						     begin
							ones_place <= 6;
							tens_place <= 6;
							if(new_clock)
							  begin
							     randOkayCounter <= 0;
							     randOkay = randOkay + 1;
							  end
						     end
						 endcase
					      end
					    else
					      begin
						 case(random1)
						   1: tens_die <= 1;
						   2: tens_die <= 2;
						   3: tens_die <= 3;
						   4: tens_die <= 4;
						   5: tens_die <= 5;
						   6: tens_die <= 6;
						   7: tens_die <= 6;
						 endcase
    						 tens_place <= tens_die;
						 
    						 //Set Display to the Generated Values
						 
						 case(random2)
						   0: ones_die <= 1;
    						   1: ones_die <= 1;
						   2: ones_die <= 2;
						   3: ones_die <= 3;
						   4: ones_die <= 4;
						   5: ones_die <= 5;
						   6: ones_die <= 6;
    						   7: ones_die <= 6;
						 endcase
						 ones_place <= ones_die;
    						 //Store the sum of both dice
    						 sum_of_dice <= tens_die + ones_die;
    						 if(change_clock)
    						   delay_fsm = 1;
    					      end
					 end
				       1:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 2;
					      end
					 end
				       2:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 3;
					      end
					 end
				       3:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 3;//Set to blank
						 player_num_place <= 5; //Set to blank
						 tens_place <= 8; //Set to blank
						 ones_place <= 10; //Set to blank
						 delay_fsm = 4;
					      end
					 end
				       4:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 0;//Set to P
						 player_num_place <= 2; //Set to Player 1
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment Start
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //Remove from the First Player's Box the Value at the Index - 1
						 player_2_box[sum_of_dice - 2] <= 0;
						 
						 case(sum_of_dice) // display sum in tens_place and ones_place
						   2:
						     begin
							tens_place <= 0;
							ones_place <= 2;
						     end
						   3:
						     begin
							tens_place <= 0;
							ones_place <= 3;
						     end
						   4:
						     begin
							tens_place <= 0;
							ones_place <= 4;
						     end
						   5:
						     begin
							tens_place <= 0;
							ones_place <= 5;
						     end
						   6:
						     begin
							tens_place <= 0;
							ones_place <= 6;
						     end
						   7:
						     begin
							tens_place <= 0;
							ones_place <= 7;
						     end
						   8:
						     begin
							tens_place <= 0;
							ones_place <= 8;
						     end
						   9:
						     begin
							tens_place <= 0;
							ones_place <= 9;
						     end
						   10:
						     begin
							tens_place <= 1;
							ones_place <= 0;
						     end
						   11:
						     begin
							tens_place <= 1;
							ones_place <= 1;
						     end
						   12:
						     begin
							tens_place <= 1;
							ones_place <= 2;
						     end
						 endcase
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment End
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 delay_fsm = 5;
					      end
					 end
				       5:
					 begin
					    if(change_clock)
					      delay_fsm = 6;
					 end
				       6:
					 begin
					    if(change_clock)
					      delay_fsm = 7;
					 end
				       7:
					 begin
					    //check if the player hasn't won
					    if(player_2_box_left != 0)
					      begin
						 rollPressed <= 0;
						 tens_place <= 0;
    						 ones_place <= 0;
						 player_turn_counter = 0;
    						 delay_fsm = 0;
					      end
					    else
					      begin
						 //set display to End Game Mode
						 //EG P1
						 //Constantly Flash in and out
						 if(flash_clock)
						   begin
						      p_disp <= 2;//Set to E
						      player_num_place <= 0; //Set to G
						      tens_place <= 7; //Set to P
						      ones_place <= 2; //Set to 1
						   end
						 else
						   begin
						      p_disp <= 3;//Set to blank
						      player_num_place <= 5; //Set to blank
						      tens_place <= 8; //Set to blank
						      ones_place <= 10; //Set to blank
						   end
					      end
					 end
				     endcase
				  end
			     end
			end
		    endcase
		 end
	       //ADDD in for 3 player game
	       3: //Two Players
		 begin
		    case(player_turn_counter)
		      0: //First Player Turn
			begin
			   player_num_place <= 1;
			   player_1_box_left = player_1_box[0] + player_1_box[1] + player_1_box[2] + player_1_box[3] + player_1_box[4] + player_1_box[5] + 
					       | player_1_box[6] + player_1_box[7] + player_1_box[8]  + player_1_box[9] + player_1_box[10];
			   
			   if(score_mode && !rollPressed)
			     begin
				p_disp <= 1;
				case(player_1_box_left) // display sum in tens_place and ones_place
				  1:
				    begin
				       tens_place <= 0;
				       ones_place <= 1;
				    end
				  2:
				    begin
				       tens_place <= 0;
				       ones_place <= 2;
				    end
				  3:
				    begin
				       tens_place <= 0;
				       ones_place <= 3;
				    end
				  4:
				    begin
				       tens_place <= 0;
				       ones_place <= 4;
				    end
				  5:
				    begin
				       tens_place <= 0;
				       ones_place <= 5;
				    end
				  6:
				    begin
				       tens_place <= 0;
				       ones_place <= 6;
				    end
				  7:
				    begin
				       tens_place <= 0;
				       ones_place <= 7;
				    end
				  8:
				    begin
				       tens_place <= 0;
				       ones_place <= 8;
				    end
				  9:
				    begin
				       tens_place <= 0;
				       ones_place <= 9;
				    end
				  10:
				    begin
				       tens_place <= 1;
				       ones_place <= 0;
				    end
				  11:
				    begin
				       tens_place <= 1;
				       ones_place <= 1;
				    end
				  
				endcase
			     end
			   else
			     begin
				i(!rollPressed)
				  begin
				     tens_place <= 0;
				     ones_place <= 0;
				  end
				p_disp <= 0;
				
				//Check if the Roll Button is Pressed and initial state
				if(roll)
				  begin
				     rollPressed <= 1;
				     randOkayCounter <= 0;
				     randOkay = 0;
				  end
				
				if(rollPressed)
				  begin
				     case(delay_fsm)
				       0:
					 begin
					    if(randOkay < 5)
					      begin
						 case (randOkayCounter)
						   0:
						     begin
							ones_place <= 1;
							tens_place <= 1;
							if(new_clock)
							  randOkayCounter <= 1;
						     end
						   1:
						     begin
							ones_place <= 2;
							tens_place <= 2;
							if(new_clock)
							  randOkayCounter <= 2;
						     end
						   2:
						     begin
							ones_place <= 3;
							tens_place <= 3;
							if(new_clock)
							  randOkayCounter <= 3;
						     end
						   3:
						     begin
							ones_place <= 4;
							tens_place <= 4;
							if(new_clock)
							  randOkayCounter <= 4;
						     end
						   4:
						     begin
							ones_place <= 5;
							tens_place <= 5;
							if(new_clock)
							  randOkayCounter <= 5;
						     end
						   5:
						     begin
							ones_place <= 6;
							tens_place <= 6;
							if(new_clock)
							  begin
							     randOkayCounter <= 0;
							     randOkay = randOkay + 1;
							  end
						     end
						 endcase
					      end
					    else
					      begin
						 case(random1)
						   1: tens_die <= 1;
						   2: tens_die <= 2;
						   3: tens_die <= 3;
						   4: tens_die <= 4;
						   5: tens_die <= 5;
						   6: tens_die <= 6;
						   7: tens_die <= 6;
						 endcase
						 tens_place <= tens_die;
						 
						 case(random2)
						   0: ones_die <= 1;
						   1: ones_die <= 1;
						   2: ones_die <= 2;
						   3: ones_die <= 3;
						   4: ones_die <= 4;
						   5: ones_die <= 5;
						   6: ones_die <= 6;
						   7: ones_die <= 6;
						 endcase
						 
						 ones_place <= ones_die;
  						 //Store the sum of both dice
  						 sum_of_dice <= tens_die + ones_die;
  						 if(change_clock)
  						   delay_fsm = 1;
					      end
					 end
				       1:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 2;
					      end
					 end
				       2:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 3;
					      end
					 end
				       3:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 3;//Set to blank
						 player_num_place <= 5; //Set to blank
						 tens_place <= 8; //Set to blank
						 ones_place <= 10; //Set to blank
						 delay_fsm = 4;
					      end
					 end
				       4:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 0;//Set to P
						 player_num_place <= 1; //Set to Player 1
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment Start
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //Remove from the First Player's Box the Value at the Index - 1
						 player_1_box[sum_of_dice - 2] <= 0;
						 
						 case(sum_of_dice) // display sum in tens_place and ones_place
						   2:
						     begin
							tens_place <= 0;
							ones_place <= 2;
						     end
						   3:
						     begin
							tens_place <= 0;
							ones_place <= 3;
						     end
						   4:
						     begin
							tens_place <= 0;
							ones_place <= 4;
						     end
						   5:
						     begin
							tens_place <= 0;
							ones_place <= 5;
						     end
						   6:
						     begin
							tens_place <= 0;
							ones_place <= 6;
						     end
						   7:
						     begin
							tens_place <= 0;
							ones_place <= 7;
						     end
						   8:
						     begin
							tens_place <= 0;
							ones_place <= 8;
						     end
						   9:
						     begin
							tens_place <= 0;
							ones_place <= 9;
						     end
						   10:
						     begin
							tens_place <= 1;
							ones_place <= 0;
						     end
						   11:
						     begin
							tens_place <= 1;
							ones_place <= 1;
						     end
						   12:
						     begin
							tens_place <= 1;
							ones_place <= 2;
						     end
						 endcase
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment End
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 delay_fsm = 5;
					      end
					 end
				       5:
					 begin
					    if(change_clock)
					      delay_fsm = 6;
					 end
				       6:
					 begin
					    if(change_clock)
					      delay_fsm = 7;
					 end
				       7:
					 begin
					    //check if the player hasn't won
					    if(player_1_box_left != 0)
					      begin
						 rollPressed <= 0;
						 tens_place <= 0;
						 ones_place <= 0;
						 player_turn_counter = 1;
						 delay_fsm = 0;
					      end
					    else
					      begin
						 //set display to End Game Mode
						 //EG P1
						 //Constantly Flash in and out
						 if(flash_clock)
						   begin
						      p_disp <= 2;//Set to E
						      player_num_place <= 0; //Set to G
						      tens_place <= 7; //Set to P
						      ones_place <= 1; //Set to 1
						   end
						 else
						   begin
						      p_disp <= 3;//Set to blank
						      player_num_place <= 5; //Set to blank
						      tens_place <= 8; //Set to blank
						      ones_place <= 10; //Set to blank
						   end
					      end
					 end
				     endcase
				  end
			     end
			end
		      1: //Second Player Turn
			begin
			   player_num_place <= 2;
			   player_2_box_left = player_2_box[0] + player_2_box[1] + player_2_box[2] + player_2_box[3] + player_2_box[4] + player_2_box[5] + 
					       | player_2_box[6] + player_2_box[7] + player_2_box[8]  + player_2_box[9] + player_2_box[10];
			   //Check if the Roll Button is Pressed and initial state
			   if(score_mode && !rollPressed)
			     begin
				p_disp <= 1;
				case(player_2_box_left) // display sum in tens_place and ones_place
				  1:
				    begin
				       tens_place <= 0;
				       ones_place <= 1;
				    end
				  2:
				    begin
				       tens_place <= 0;
				       ones_place <= 2;
				    end
				  3:
				    begin
				       tens_place <= 0;
				       ones_place <= 3;
				    end
				  4:
				    begin
				       tens_place <= 0;
				       ones_place <= 4;
				    end
				  5:
				    begin
				       tens_place <= 0;
				       ones_place <= 5;
				    end
				  6:
				    begin
				       tens_place <= 0;
				       ones_place <= 6;
				    end
				  7:
				    begin
				       tens_place <= 0;
				       ones_place <= 7;
				    end
				  8:
				    begin
				       tens_place <= 0;
				       ones_place <= 8;
				    end
				  9:
				    begin
				       tens_place <= 0;
				       ones_place <= 9;
				    end
				  10:
				    begin
				       tens_place <= 1;
				       ones_place <= 0;
				    end
				  11:
				    begin
				       tens_place <= 1;
				       ones_place <= 1;
				    end
				endcase
			     end
			   else
			     begin
				if(!rollPressed)
				  begin
				     tens_place <= 0;
				     ones_place <= 0;
				  end
				p_disp <= 0;
				
				if(roll)
				  begin
				     rollPressed <= 1;
				     randOkayCounter <= 0;
				     randOkay = 0;
				  end
				if(rollPressed)
				  begin
				     case(delay_fsm)
				       0:
					 begin
    					    if(randOkay < 5)
    					      begin
    						 case (randOkayCounter)
    						   0:
    						     begin
    							ones_place <= 1;
    							tens_place <= 1;
    							if(new_clock)
    							  randOkayCounter <= 1;
    						     end
    						   1:
    						     begin
    							ones_place <= 2;
    							tens_place <= 2;
    							if(new_clock)
    							  randOkayCounter <= 2;
    						     end
    						   2:
    						     begin
    							ones_place <= 3;
    							tens_place <= 3;
    							if(new_clock)
    							  randOkayCounter <= 3;
    						     end
    						   3:
    						     begin
    							ones_place <= 4;
    							tens_place <= 4;
    							if(new_clock)
    							  randOkayCounter <= 4;
    						     end
    						   4:
    						     begin
    							ones_place <= 5;
    							tens_place <= 5;
    							if(new_clock)
    							  randOkayCounter <= 5;
    						     end
    						   5:
    						     begin
    							ones_place <= 6;
    							tens_place <= 6;
    							if(new_clock)
    							  begin
    							     randOkayCounter <= 0;
    							     randOkay = randOkay + 1;
    							  end
    						     end
    						 endcase
					      end
					    else
					      begin
						 case(random1)
						   1: tens_die <= 1;
						   2: tens_die <= 2;
						   3: tens_die <= 3;
						   4: tens_die <= 4;
						   5: tens_die <= 5;
						   6: tens_die <= 6;
  						   7: tens_die <= 6;
						 endcase
						 
						 tens_place <= tens_die;
						 
						 //Set Display to the Generated Values
						 
						 case(random2)
						   0: ones_die <= 1;
						   1: ones_die <= 1;
						   2: ones_die <= 2;
						   3: ones_die <= 3;
						   4: ones_die <= 4;
						   5: ones_die <= 5;
						   6: ones_die <= 6;
						   7: ones_die <= 6;
						 endcase
						 ones_place <= ones_die;
						 
  						 //Store the sum of both dice
  						 sum_of_dice <= tens_die + ones_die;
						 
  						 if(change_clock)
  						   delay_fsm = 1;
  					      end
					 end
				       1:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 2;
					      end
					 end
				       2:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 3;
					      end
					 end
				       3:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 3;//Set to blank
						 player_num_place <= 5; //Set to blank
						 tens_place <= 8; //Set to blank
						 ones_place <= 10; //Set to blank
						 delay_fsm = 4;
					      end
					 end
				       4:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 0;//Set to P
						 player_num_place <= 2; //Set to Player 1
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment Start
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //Remove from the First Player's Box the Value at the Index - 1
						 player_2_box[sum_of_dice - 2] <= 0;
						 
						 case(sum_of_dice) // display sum in tens_place and ones_place
						   2:
						     begin
							tens_place <= 0;
							ones_place <= 2;
						     end
						   3:
						     begin
							tens_place <= 0;
							ones_place <= 3;
						     end
						   4:
						     begin
							tens_place <= 0;
							ones_place <= 4;
						     end
						   5:
						     begin
							tens_place <= 0;
							ones_place <= 5;
						     end
						   6:
						     begin
							tens_place <= 0;
							ones_place <= 6;
						     end
						   7:
						     begin
							tens_place <= 0;
							ones_place <= 7;
						     end
						   8:
						     begin
							tens_place <= 0;
							ones_place <= 8;
						     end
						   9:
						     begin
							tens_place <= 0;
							ones_place <= 9;
						     end
						   10:
						     begin
							tens_place <= 1;
							ones_place <= 0;
						     end
						   11:
						     begin
							tens_place <= 1;
							ones_place <= 1;
						     end
						   12:
						     begin
							tens_place <= 1;
							ones_place <= 2;
						     end
						 endcase
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment End
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 delay_fsm = 5;
					      end
					 end
				       5:
					 begin
					    if(change_clock)
					      delay_fsm = 6;
					 end
				       6:
					 begin
					    if(change_clock)
					      delay_fsm = 7;
					 end
				       7:
					 begin
					    //check if the player hasn't won
					    if(player_2_box_left != 0)
					      begin
						 rollPressed <= 0;
    						 tens_place <= 0;
    						 ones_place <= 0;
						 player_turn_counter = 2;
						 delay_fsm = 0;
					      end
					    else
					      begin
						 //set display to End Game Mode
						 //EG P1
						 //Constantly Flash in and out
						 if(flash_clock)
						   begin
						      p_disp <= 2;//Set to E
						      player_num_place <= 0; //Set to G
						      tens_place <= 7; //Set to P
						      ones_place <= 2; //Set to 2
						   end
						 else
						   begin
						      p_disp <= 3;//Set to blank
						      player_num_place <= 5; //Set to blank
						      tens_place <= 8; //Set to blank
						      ones_place <= 10; //Set to blank
						   end
					      end
					 end
				     endcase
				  end
			     end //
			end
		      ////THIRD PLAYER START
		      2: //First Player Turn
			begin
			   player_num_place <= 3;
			   player_3_box_left = player_3_box[0] + player_3_box[1] + player_3_box[2] + player_3_box[3] + player_3_box[4] + player_3_box[5] + 
					       | player_3_box[6] + player_3_box[7] + player_3_box[8]  + player_3_box[9] + player_3_box[10];
			   
			   if(score_mode && !rollPressed)
			     begin
				p_disp <= 1;
				case(player_3_box_left) // display sum in tens_place and ones_place
				  1:
				    begin
				       tens_place <= 0;
				       ones_place <= 1;
				    end
				  2:
				    begin
				       tens_place <= 0;
				       ones_place <= 2;
				    end
				  3:
				    begin
				       tens_place <= 0;
				       ones_place <= 3;
				    end
				  4:
				    begin
				       tens_place <= 0;
				       ones_place <= 4;
				    end
				  5:
				    begin
				       tens_place <= 0;
				       ones_place <= 5;
				    end
				  6:
				    begin
				       tens_place <= 0;
				       ones_place <= 6;
				    end
				  7:
				    begin
				       tens_place <= 0;
				       ones_place <= 7;
				    end
				  8:
				    begin
				       tens_place <= 0;
				       ones_place <= 8;
				    end
				  9:
				    begin
				       tens_place <= 0;
				       ones_place <= 9;
				    end
				  10:
				    begin
				       tens_place <= 1;
				       ones_place <= 0;
				    end
				  11:
				    begin
				       tens_place <= 1;
				       ones_place <= 1;
				    end
				endcase
			     end
			   else
			     begin
				if(!rollPressed)
				  begin
				     tens_place <= 0;
				     ones_place <= 0;
				  end
				p_disp <= 0;
				
				//Check if the Roll Button is Pressed and initial state
				
  				if(roll)
  				  begin
  				     rollPressed <= 1;
  				     randOkayCounter <= 0;
  				     randOkay = 0;
  				  end
				
  				if(rollPressed)
  				  begin
				     case(delay_fsm)
				       0:
					 begin
  					    if(randOkay < 5)
  					      begin
  						 case (randOkayCounter)
  						   0:
  						     begin
  							ones_place <= 1;
  							tens_place <= 1;
  							if(new_clock)
  							  randOkayCounter <= 1;
  						     end
  						   1:
  						     begin
  							ones_place <= 2;
  							tens_place <= 2;
  							if(new_clock)
  							  randOkayCounter <= 2;
  						     end
  						   2:
  						     begin
  							ones_place <= 3;
  							tens_place <= 3;
  							if(new_clock)
  							  randOkayCounter <= 3;
  						     end
  						   3:
  						     begin
  							ones_place <= 4;
  							tens_place <= 4;
  							if(new_clock)
  							  randOkayCounter <= 4;
  						     end
  						   4:
  						     begin
  							ones_place <= 5;
  							tens_place <= 5;
  							if(new_clock)
  							  randOkayCounter <= 5;
  						     end
  						   5:
  						     begin
  							ones_place <= 6;
  							tens_place <= 6;
  							if(new_clock)
  							  begin
  							     randOkayCounter <= 0;
  							     randOkay = randOkay + 1;
  							  end
  						     end
  						 endcase
					      end
					    else
					      begin
						 case(random1)
						   1: tens_die <= 1;
						   2: tens_die <= 2;
						   3: tens_die <= 3;
						   4: tens_die <= 4;
						   5: tens_die <= 5;
						   6: tens_die <= 6;
  						   7: tens_die <= 6;
						 endcase
  						 tens_place <= tens_die;
  						 //Set Display to the Generated Values
						 case(random2)
						   0: ones_die <= 1;
  						   1: ones_die <= 1;
						   2: ones_die <= 2;
						   3: ones_die <= 3;
						   4: ones_die <= 4;
						   5: ones_die <= 5;
						   6: ones_die <= 6;
  						   7: ones_die <= 6;
						 endcase
						 ones_place <= ones_die;
						 
  						 //Store the sum of both dice
  						 sum_of_dice <= tens_die + ones_die;
  						 if(change_clock)
  						   delay_fsm = 1;
  					      end
					 end
				       1:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 2;
					      end
					 end
				       2:
					 begin
					    if(change_clock)
					      begin
						 delay_fsm = 3;
					      end
					 end
				       3:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 3;//Set to blank
						 player_num_place <= 5; //Set to blank
						 tens_place <= 8; //Set to blank
						 ones_place <= 10; //Set to blank
						 delay_fsm = 4;
					      end
					 end
				       4:
					 begin
					    if(change_clock)
					      begin
						 p_disp <= 0;//Set to P
						 player_num_place <= 3; //Set to Player 1
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment Start
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //Remove from the First Player's Box the Value at the Index - 1
						 player_3_box[sum_of_dice - 2] <= 0;
						 
						 case(sum_of_dice) // display sum in tens_place and ones_place
						   2:
						     begin
							tens_place <= 0;
							ones_place <= 2;
						     end
						   3:
						     begin
							tens_place <= 0;
							ones_place <= 3;
						     end
						   4:
						     begin
							tens_place <= 0;
							ones_place <= 4;
						     end
						   5:
						     begin
							tens_place <= 0;
							ones_place <= 5;
						     end
						   6:
						     begin
							tens_place <= 0;
							ones_place <= 6;
						     end
						   7:
						     begin
							tens_place <= 0;
							ones_place <= 7;
						     end
						   8:
						     begin
							tens_place <= 0;
							ones_place <= 8;
						     end
						   9:
						     begin
							tens_place <= 0;
							ones_place <= 9;
						     end
						   10:
						     begin
							tens_place <= 1;
							ones_place <= 0;
						     end
						   11:
						     begin
							tens_place <= 1;
							ones_place <= 1;
						     end
						   12:
						     begin
							tens_place <= 1;
							ones_place <= 2;
						     end
						 endcase
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 //									//Display Sum on Seven Segment End
						 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						 delay_fsm = 5;
					      end
					 end
				       5:
					 begin
					    if(change_clock)
					      delay_fsm = 6;
					 end
				       6:
					 begin
					    if(change_clock)
					      delay_fsm = 7;
					 end
				       7:
					 begin
					    //check if the player hasn't won
					    if(player_3_box_left != 0)
					      begin
						 rollPressed <= 0;
						 tens_place <= 0;
						 ones_place <= 0;
						 player_turn_counter = 0;
						 delay_fsm = 0;
					      end
					    else
					      begin
						 //set display to End Game Mode
						 //EG P1
						 //Constantly Flash in and out
						 if(flash_clock)
						   begin
						      p_disp <= 2;//Set to E
						      player_num_place <= 0; //Set to G
						      tens_place <= 7; //Set to P
						      ones_place <= 3; //Set to 3
						   end
						 else
						   begin
						      p_disp <= 3;//Set to blank
						      player_num_place <= 5; //Set to blank
						      tens_place <= 8; //Set to blank
						      ones_place <= 10; //Set to blank
						   end
					      end
					 end
				     endcase
				  end
			     end
			end
		    endcase
		 end
	     endcase
	  end
     end
   
end
   
endmodule

/*****************/
/* CLOCK DIVIDER */
/*****************/
module clock_divider (
    //inputs
    master_clk,
    //output
    fast_clk, change_clk, flash_clk, new_clk
);

input master_clk;
output fast_clk, change_clk, flash_clk, new_clk;
reg fast_clk, change_clk, flash_clk, new_clk;

reg [26:0] fast_count = 0;
reg [26:0] change_count = 0;
reg [26:0] flash_count = 0;
reg [26:0] new_count = 0;

initial begin
   fast_clk <= 0;
   change_clk <= 0;
   flash_clk <= 0;
   new_clk <= 0;
end
   
always @ (posedge master_clk) begin
   if (fast_count == 195000) begin
      fast_count <= 0;
      fast_clk = !fast_clk;
   end
   else begin
      fast_count <= fast_count + 1;
   end
end

always @ (posedge master_clk) begin
   if (change_count == 100000000) begin
      change_count <= 0;
      change_clk <= 1;
   end
   else begin
      change_clk <= 0;
      change_count <= change_count + 1;
   end
end

always @ (posedge master_clk) begin
   if (flash_count == 10000000) begin
      flash_count <= 0;
      flash_clk <= !flash_clk;
   end
   else begin
      flash_count <= flash_count + 1;
   end
end

always @ (posedge master_clk) begin
   if (new_count == 10000000) begin
      new_count <= 0;
      new_clk <= 1;
   end
   else begin
      new_clk <= 0;
      new_count <= new_count + 1;
   end
end

endmodule

/***************/
/* SCORE BOARD */
/***************/
module display_seg (
    //inputs
    change_clk, fast_clk, ones_place, tens_place, p_disp, score_mode, 
		number_of_players, player_num_place,
    //output
    seg, an
);

input change_clk, fast_clk, score_mode;
input [3:0] ones_place, tens_place;
input [1:0] p_disp;
input [2:0] player_num_place;
input [1:0] number_of_players;

output reg [7:0] seg;
output reg [3:0] an;

reg [1:0] state; //for clock/seven seg iteration

always @(posedge fast_clk)
  begin
     case(state)
	   0:
		 begin
			 state = state + 1;
			 an <= 4'b0111;
		 end
		1:
		 begin
			 state = state + 1;
			 an <= 4'b1011;
		 end
		2:
		 begin
			 state = state + 1;
			 an <= 4'b1101;
		 end
		3:
		 begin
			 state = state + 1;
			 an <= 4'b1110;
		 end
     endcase
  end

localparam zero = 8'b11000000;
localparam one = 8'b11111001;
localparam two = 8'b10100100;
localparam three = 8'b10110000;
localparam four = 8'b10011001;
localparam five = 8'b10010010;
localparam six = 8'b10000010;
localparam seven = 8'b11111000;
localparam eight = 8'b10000000;
localparam nine = 8'b10011000;
localparam letter_p = 8'b10001100;
localparam letter_s = 8'b10010010;
localparam letter_e = 8'b10000110;
localparam letter_g = 8'b11000010;
localparam blank = 8'b11111111;

always @*
  begin
     if (an == 4'b0111)
       begin
		  case(p_disp)
			 0: seg <= letter_p;
			 1: seg <= letter_s;
			 2: seg <= letter_e;
			 3: seg <= blank;
			 default: seg <= 8'b10111111;
		  endcase
       end
     else if (an == 4'b1011)
       begin
		  case(player_num_place)
			 0: seg <= letter_g;
			 1: seg <= one;
			 2: seg <= two;
			 3: seg <= three;
			 4: seg <= four;
			 5: seg <= blank;
			 default: seg <= 8'b10111111;
		  endcase
       end
     else if (an == 4'b1101)
       begin
		  case(tens_place)
			 0: seg <= zero;
			 1: seg <= one;
			 2: seg <= two;
			 3: seg <= three;
			 4: seg <= four;
			 5: seg <= five;
			 6: seg <= six;
			 7: seg <= letter_p;
			 8: seg <= blank;
			 default: seg <= 8'b10111111;
		  endcase
       end
     else if (an == 4'b1110)
       begin
		  case(ones_place)
			 0: seg <= zero;
			 1: seg <= one;
			 2: seg <= two;
			 3: seg <= three;
			 4: seg <= four;
			 5: seg <= five;
			 6: seg <= six;
			 7: seg <= seven;
			 8: seg <= eight;
			 9: seg <= nine;
			 10: seg <= blank;
			 default: seg <= 8'b10111111;
		  endcase
       end
     else
       seg <= 8'b00000000;
  end
   
endmodule
