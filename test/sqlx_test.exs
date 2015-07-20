defmodule SqlxTest do
  use ExUnit.Case
  require Sqlx

  test "prepare queries" do
    assert "123,'qwe',1.33,2,3,4" == Sqlx.prepare_query("?,?", [123, ["qwe", 1.33, 2, 3, 4]])
  end

  test "data test" do
	%{error: [], ok: [Sqlx.ok_packet()]} = 	"DELETE FROM test_tab;" 
											|> Sqlx.exec([], :mysql) # third arg - pool name
	%{error: [], ok: [Sqlx.ok_packet()]} = 	"INSERT INTO test_tab (comment, ballance) VALUES (?),(?);" 
											|> Sqlx.exec([["qwe",1],["ewq",2]]) # by default use :mysql pool name
	%{error: [], ok: [Sqlx.ok_packet(),Sqlx.ok_packet()]} = """
															INSERT INTO test_tab (comment, ballance) VALUES (?),(?);
															UPDATE test_tab SET ballance = 0 WHERE ballance = ?;
															"""
															|> Sqlx.exec([["q\\\'w'e\\'",3],["e,wq\\",4],4])
	[	%{id: id1, ballance: 0, comment: "e,wq\\"},
		%{id: id2, ballance: 1, comment: "qwe"},
		%{id: id3, ballance: 2, comment: "ewq"},
		%{id: id4, ballance: 3, comment: "q'w'e'"} ] = "SELECT * FROM test_tab;" 
													 |> Sqlx.exec([]) 
													 |> Enum.sort_by(fn(%{ballance: b}) -> b end)

	%{error: [Sqlx.error_packet()], ok: []} = "SELECT * FROM unknown_tab;" |> Sqlx.exec([])
	assert Enum.all?([id1, id2, id3, id4], &is_integer/1)
	#
	#	smart inserts
	#
	"DELETE FROM test_tab;" |> Sqlx.exec([], :mysql)
	data = [%{comment: "ONE", ballance: 1}, %{comment: "TWO", ballance: 2}, %{comment: "THREE", ballance: 3}]
	Sqlx.insert(data, [:comment, :ballance], "test_tab")
	Sqlx.insert_ignore(data, [:comment, :ballance], "test_tab")
	Sqlx.insert_duplicate(data, [:comment, :ballance], [], "test_tab")
	assert Enum.sort(data++data++data) == ("SELECT comment, ballance FROM test_tab") |> Sqlx.exec([]) |> Enum.sort
	%{error: [], ok: []} = Sqlx.insert([], [:comment, :ballance], "test_tab")
	%{error: [], ok: []} = Sqlx.insert_ignore([], [:comment, :ballance], "test_tab")
	%{error: [], ok: []} = Sqlx.insert_duplicate([], [:comment, :ballance], [], "test_tab")
	#
	#	try to break
	#
	"INSERT INTO test_tab (comment, ballance) VALUES (?);" |> Sqlx.exec([["(DELETE FROM test_tab;)",3]])
	"INSERT INTO test_tab (comment, ballance) VALUES (?);" |> Sqlx.exec([["'DELETE FROM test_tab\\",3]])
	assert 11 == Sqlx.exec("SELECT * FROM test_tab;", []) |> IO.inspect |> length
  end

end
