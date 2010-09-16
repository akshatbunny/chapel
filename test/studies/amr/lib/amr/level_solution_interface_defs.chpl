use level_interface_defs;



//|""""""""""""""""""""""""""""""""""""\
//|===> LevelSolutionInterface class ===>
//|____________________________________/
class LevelSolutionInterface {

  const level_interface: LevelInterface;
  var fine_ghost_arrays: [1..2] LevelGhostArray;
  var time:              [1..2] real;

  def LevelSolutionInterface(level_interface: LevelInterface) {
    this.level_interface = level_interface;
    for i in [1..2] do
      fine_ghost_arrays(i) = new LevelGhostArray(level_interface.fine_level);
  }


  def fillFineGhostArrays_Linear(coarse_sol: LevelSolution) {
    for i in [1..2] {
      time(i) = coarse_sol.time(i);
      fine_ghost_arrays(i).interpolateFromCoarse_Linear(coarse_sol.space_data(i));
    }
  }


  def correctCoarseSolution_Linear(
    coarse_sol: LevelSolution,
    fine_sol:   LevelSolution)
  {
    assert( abs(coarse_sol.time(2) - fine_sol.time(2)) < 1.0e-8,
	    "Warning: correctCoarseInterior_Linear\n" +
	    "  Time of fine solution may not agree with time of coarse solution");

    coarse_sol.space_data(2).interpolateFromFine_Linear(fine_sol.space_data(2));
  }

}
// /""""""""""""""""""""""""""""""""""""|
//<=== LevelSolutionInterface class <===|
// \____________________________________|






//|""""""""""""""""""""""""""""""""""""""""""""""""""""\
//|===> LevelGhostArray.interpolateFromCoarse_Linear ===>
//|____________________________________________________/
def LevelGhostArray.interpolateFromCoarse_Linear(q_coarse: LevelArray)
{

  for grid in level.grids {
    ghost_arrays(grid).interpolateFromCoarse_Linear(q_coarse);
  }

}
// /""""""""""""""""""""""""""""""""""""""""""""""""""""|
//<=== LevelGhostArray.interpolateFromCoarse_Linear <===|
// \____________________________________________________|




//|""""""""""""""""""""""""""""""""""""""""""""""""""""""\
//|===> GhostArray.interpolateFromCoarse_Linear method ===>
//|______________________________________________________/
def GhostArray.interpolateFromCoarse_Linear(
  q:         LevelArray,
  interface: LevelInterface)
{
  var overlap: domain(dimension, stridable=true);
 
  for coarse_grid in interface.coarse_neighbors(this.grid) {
    for loc in ghost_locations {

      overlap = ghost_cells(loc)( interface.refine(coarse_grid) );

      if intersection.numIndices > 0 then
	arrays(loc).value(intersection) = 
	  q(coarse_grid).interpolateToFine_Linear(overlap, interface);

    }
  }

}
// /""""""""""""""""""""""""""""""""""""""""""""""""""""""|
//<=== GhostArray.interpolateFromCoarse_Linear method <===|
// \______________________________________________________|




//|"""""""""""""""""""""""""""""""""""""""""""""\
//|===> GridArray.extrapolateGhostData method ===>
//|_____________________________________________/
//-----------------------------------------------------------------
// Fills the first layer of ghost cells with linearly extrapolated
// data from the interior.
//-----------------------------------------------------------------
def GridArray.extrapolateGhostData() {

  var shift: dimension*int;

  for loc in ghost_locations {
    //==== Create index pointing towards interior ====
    shift = 2*loc;
    
    forall cell in grid.ghost_cells(loc) do
      value(cell) = 2.0*value(cell+shift) - value(cell+2*shift);    
  }

}
// /"""""""""""""""""""""""""""""""""""""""""""""|
//<=== GridArray.extrapolateGhostData method <===|
// \_____________________________________________|





//|"""""""""""""""""""""""""""""""""""""""""""""""""\
//|===> GridArray.interpolateToFine_Linear method ===>
//|_________________________________________________/
def GridArray.interpolateToFine_Linear(
  fine_cells: domain(dimension, stridable=true)
  interface:  LevelInterface)
{
  
  extrapolateGhostData();

  var coarse_cells = grid.cells( interface.coarsen(fine_cells) );
  var coarse_values = value(coarse_cells);
  var coarse_diffs: [coarse_cells] [dimensions] real;


  //===> Form interpolant data (values and differentials ===>
  forall cell in coarse_cells {
    var diff_mag, diff_sign, diff_low, diff_high, diff_cen: real;
    var shift: dimension*int;

    for d in dimensions {
      shift *= 0;
      shift(d) = 2;

      diff_low  = value(cell) - value(cell-shift);
      diff_high = value(cell+shift) - value(cell);
      diff_cen  = (diff_high - diff_low) / 2.0;

      if diff_low*diff_high > 0 {
	diff_sign = diff_low / abs(diff_low);
	diff_mag = min( abs(diff_low), abs(diff_high), abs(diff_cen) );
	coarse_diffs(cell)(d) = diff_sign * diff_mag;
      }
      else
	coarse_diffs(cell)(d) = 0.0;
    }
  }
  //<=== Form interpolant data (values and differentials) <===


  //===> Evaluate interpolant on fine cells ===>
  var fine_values: [fine_cells] real;

  forall fine_cell in fine_cells {
    var coarse_cell = interface.coarsen(fine_cell);
    fine_values(fine_cell) = coarse_values(coarse_cell);

    var fine_displacement: real = 0.0;

    for d in dimensions {
      //==== Move to coarse indices ====
      fine_displacement = fine_cell(d):real / ref_ratio(d):real;

      //==== Compute displacement ====
      fine_displacement -= coarse_cell(d):real;

      //==== Rescale: One cell occupies 2 indices ====
      fine_displacement /= 2.0;

      //==== Modify fine_value ====
      fine_values(fine_cell) += fine_displacement * coarse_diffs(coarse_cell)(d);
    }      
    
  }
  //<=== Evaluate interpolant on fine cells <===


  return fine_values;

}
// /"""""""""""""""""""""""""""""""""""""""""""""""""|
//<=== GridArray.interpolateToFine_Linear method <===|
// \_________________________________________________|









//|"""""""""""""""""""""""""""""""""""""""""""""\
//|===> LevelArray.interpolateFromFine_Linear ===>
//|_____________________________________________/
def LevelArray.interpolateFromFine_Linear(
  q_fine:    LevelArray,
  interface: LevelInterface)
{

  for grid_array in grid_arrays do
    grid_array.interpolateFromFine_Linear(q_fine, interface);

}
// /"""""""""""""""""""""""""""""""""""""""""""""|
//<=== LevelArray.interpolateFromFine_Linear <===|
// \_____________________________________________|





//|""""""""""""""""""""""""""""""""""""""""""""\
//|===> GridArray.interpolateFromFine_Linear ===>
//|____________________________________________/
def GridArray.interpolateFromFine_Linear(
  q:         LevelArray,
  interface: LevelInterface)
{

  var overlap: domain(dimension: stridable=true);

  for fine_grid in interface.fine_neighbors(this.grid) {
    overlap = this.grid.cells( interface.coarsen(fine_grid.cells) );
    // Transfer data between processors here
    value(overlap) = q(fine_grid).interpolateToCoarse_Linear(overlap, interface);
  }

}
// /""""""""""""""""""""""""""""""""""""""""""""|
//<=== GridArray.interpolateFromFine_Linear <===|
// \____________________________________________|





//|""""""""""""""""""""""""""""""""""""""""""""\
//|===> GridArray.interpolateToCoarse_Linear ===>
//|____________________________________________/
def GridArray.interpolateToCoarse_Linear(
  coarse_cells: domain(dimension, stridable=true),
  interface:    LevelInterface)
{

  //==== Volume fraction is 1/product(ref_ratio) ====
  // Could store this in the interface...
  var volume_fraction: real = 1.0;
  for d in dimensions do
    volume_fraction /= interface.ref_ratio(d):real;

  
  //==== Compute coarse averages ====
  var coarse_values: [coarse_cells] real;

  forall coarse_cell in coarse_cells {
    var fine_cells = interface.refine(coarse_cell);
    for fine_cell in fine_cells do
      coarse_values(coarse_cell) += value(fine_cell);
    coarse_values(coarse_cell) *= volume_fraction;
  }


  return coarse_values;

}
// /""""""""""""""""""""""""""""""""""""""""""""|
//<=== GridArray.interpolateToCoarse_Linear <===|
// \____________________________________________|






//|""""""""""""""""""""""""""""""""""""""""""""""""""""""\
//|===> LevelSolutionInterface.coarseSendLinear method ===>
//|______________________________________________________/
def LevelGhostArray.coarseSendLinear(
  q: LevelSolution)
{

  for i in [1..2] {

    time(i) = coarse_sol.time(i);
    var q_level = coarse_sol.space_data(i);

    //===> Prepare ghost data ===>
    for q_grid in q_level.grid_arrays do
      q_grid.extrapolateGhostData();

    q_level.fillSharedGhosts();
    //<=== Prepare ghost data <===


    for coarse_grid in level_interface.coarse_grids {
      var sender_info     = coarse_sender_info(coarse_grid);
      var fine_ghost_cells: GhostCells;
      var ghost_domain:     domain(dimension, stridable=true);

      for fine_grid in sender_info.fine_grids {
	c2f_ghost_cells = sender_info.fine_ghost_cells(fine_grid);
	grid_ghost_data = fine_ghost_data(i)(fine_grid)

	for loc in ghost_locations {
	  ghost_domain = fine_ghost_cells(loc);
	  fine_ghost_data(i)(fine_grid)
	}
      }
    }
  }
    
}
// /""""""""""""""""""""""""""""""""""""""""""""""""""""""|
//<=== LevelSolutionInterface.coarseSendLinear method <===|
// \______________________________________________________|