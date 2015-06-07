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
															|> Sqlx.exec([["q'we",3],["e,wq",4],4])
	[	%{id: id1, ballance: 0, comment: "e,wq"},
		%{id: id2, ballance: 1, comment: "qwe"},
		%{id: id3, ballance: 2, comment: "ewq"},
		%{id: id4, ballance: 3, comment: "q'we"} ] = "SELECT * FROM test_tab;" 
													 |> Sqlx.exec([]) 
													 |> Enum.sort_by(fn(%{ballance: b}) -> b end)

	%{error: [Sqlx.error_packet()], ok: []} = "SELECT * FROM unknown_tab;" |> Sqlx.exec([])
	assert Enum.all?([id1, id2, id3, id4], &is_integer/1)
	#
	#	smart inserts
	#
	"DELETE FROM test_tab;" |> Sqlx.exec([], :mysql)
	data = [%{comment: "ONE", ballance: 1}, %{comment: "TWO", ballance: 2}, %{comment: "THREE", ballance: 3}]
	Sqlx.insert([Enum.at(data,0)], [:comment, :ballance], "test_tab")
	Sqlx.insert_ignore([Enum.at(data,1)], [:comment, :ballance], "test_tab")
	Sqlx.insert_duplicate([Enum.at(data,2)], [:comment, :ballance], [], "test_tab")
	assert Enum.sort(data) == ("SELECT comment, ballance FROM test_tab") |> Sqlx.exec([]) |> Enum.sort
  end

end
