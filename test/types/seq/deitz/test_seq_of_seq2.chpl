use List;

var s1 : list(int) = makeList(1, 2, 3, 4);
var s2 : list(int) = makeList(5, 6, 7, 8);

writeln(s1);
writeln(s2);

var ss : list(list(int)) = makeList(s1, s2);

writeln(ss);

forall s in ss do
  writeln(s);

forall s in ss do
  forall i in s do
    writeln(i);
