defmodule Sqlx do
	use Application
	use Silverb, 	[
						{"@pools", :application.get_env(:sqlx, :pools, nil)},
						{"@ttl", :application.get_env(:sqlx, :timeout, nil)},
						{"@escape_reg", [~r/(\\*')/ , ~r/(\\+)$/]},
						{"@escape_sym", "\\"}
					]
	use Logex, [ttl: 100]
	require Record
	Record.defrecord :result_packet, Record.extract(:result_packet, from_lib: "emysql/include/emysql.hrl")
	Record.defrecord :field, Record.extract(:field, from_lib: "emysql/include/emysql.hrl")
	Record.defrecord :ok_packet, Record.extract(:ok_packet, from_lib: "emysql/include/emysql.hrl")
	Record.defrecord :error_packet, Record.extract(:error_packet, from_lib: "emysql/include/emysql.hrl")


  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    :application.set_env(:emysql, :default_timeout, @ttl)
    Enum.each(@pools, fn({name, settings}) ->
    	case :emysql.add_pool(name, settings) do
    		:ok -> 	notice("init mysql pool #{inspect name}")
    		some -> error("failed to init mysql pool #{inspect name}, error #{inspect some}")
    				raise("failed to init mysql pool #{inspect name}, error #{inspect some}")
    	end
    end)


    children = [
      # Define workers and child supervisors to be supervised
      # worker(Sqlx.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sqlx.Supervisor]
    Supervisor.start_link(children, opts)
  end



	@type sqlable :: String.t | number | boolean | nil | :undefined | [sqlable]
	@type select_res :: [%{atom => any}]
	@type execute_res :: %{ok: [tuple], error: [tuple]}



	@spec prepare_query(String.t, [sqlable]) :: String.t
	def prepare_query(str, args) do
		%{
			resstr: resstr,
			args: []
		} = String.replace(str, "\n", " ")
			|> String.codepoints
			|> Enum.reduce(%{resstr: "", args: args},
				fn
				"?", %{resstr: resstr, args: [arg|rest]} -> %{resstr: resstr<>prepare_query_proc(arg), args: rest}
				some, %{resstr: resstr, args: args} -> %{resstr: resstr<>some, args: args}
				end)
		resstr
	end
	@spec prepare_query_proc(sqlable) :: String.t
	defp prepare_query_proc(bin) when is_binary(bin), do: "'"<>Enum.reduce(@escape_reg, bin, fn(reg, acc) -> Exutils.Reg.escape(acc, reg, @escape_sym) end)<>"'"
	defp prepare_query_proc(int) when is_integer(int), do: Integer.to_string(int)
	defp prepare_query_proc(flo) when is_float(flo), do: Float.to_string(flo, [decimals: 10, compact: true])
	defp prepare_query_proc(boo) when is_boolean(boo), do: Atom.to_string(boo)
	defp prepare_query_proc(lst) when is_list(lst) do
		Enum.map(lst, &prepare_query_proc/1)
		|> List.flatten
		|> Enum.join(",")
	end
	defp prepare_query_proc(nil), do: "NULL"
	defp prepare_query_proc(:undefined), do: "NULL"



	@spec exec(String.t, [sqlable], atom) :: select_res | execute_res
	def exec(query, args, pool \\ :mysql) do
		case :emysql.execute(pool, prepare_query(query, args)) do
			result_packet(rows: rows, field_list: field_list) ->
				Enum.map(field_list, fn(field(name: name)) -> String.to_atom(name) end)
				|> parse_select(rows)
			some -> [some] |> List.flatten |> check_transaction
		end
	end
	@spec parse_select([atom], [any]) :: select_res
	defp parse_select(headers, rows) do
		Enum.map(rows,
			fn(this_row) ->
				Stream.zip(headers, this_row)
				|> Enum.reduce(%{},
					fn
					{k,:undefined}, resmap -> Map.put(resmap, k, nil)
					{k,v}, resmap -> Map.put(resmap, k, v)
					end)
			end)
	end
	@spec check_transaction([tuple]) :: execute_res
	defp check_transaction(lst) do
		Enum.reduce(lst, %{ok: [], error: []},
			fn
			el = ok_packet(), resmap -> Map.update!(resmap, :ok, &([el|&1]))
			el = error_packet(), resmap -> Map.update!(resmap, :error, &([el|&1]))
			end)
	end




	@type simple_key :: String.t | atom
	@type simple_val :: String.t | number | boolean | nil | :undefined
	@type simple_input :: %{simple_key => simple_val}




	@spec insert([simple_input], [simple_key], String.t, atom) :: execute_res
	def insert(lst, keys, tab, pool \\ :mysql)
	def insert([], _, _, _), do: %{ok: [], error: []}
	def insert(lst = [_|_], keys = [_|_], tab, pool), do: insert_proc("", lst, keys, tab, pool)

	@spec insert_ignore([simple_input], [simple_key], String.t, atom) :: execute_res
	def insert_ignore(lst, keys, tab, pool \\ :mysql)
	def insert_ignore([], _, _, _), do: %{ok: [], error: []}
	def insert_ignore(lst = [_|_], keys = [_|_], tab, pool), do: insert_proc("IGNORE", lst, keys, tab, pool)
	defp insert_proc(mod, lst, keys, tab, pool) do
		"""
		INSERT #{mod} INTO #{tab}
		(#{Enum.join(keys, ",")})
		VALUES
		#{Stream.map(lst, fn(_) -> "(?)" end) |> Enum.join(",")};
		"""
		|> exec(Enum.map(lst, &(make_args(&1, keys))), pool)
	end

	@spec insert_duplicate([simple_input], [simple_key], [simple_key], String.t, atom) :: execute_res
	def insert_duplicate(lst, keys, uniq_keys, tab, pool \\ :mysql)
	def insert_duplicate([], _, _, _, _), do: %{ok: [], error: []}
	def insert_duplicate(lst = [_|_], keys = [_|_], uniq_keys, tab, pool) when is_list(uniq_keys) do
		case 	Stream.filter_map(keys, &(not(Enum.member?(uniq_keys,&1))), &("#{&1} = VALUES(#{&1})"))
				|> Enum.join(",") do
			"" -> raise("#{__MODULE__ |> Atom.to_string} : no any duplication part of query.. keys #{inspect keys}..  uniq_keys #{inspect uniq_keys}")
			dupl ->
				"""
				INSERT INTO #{tab}
				(#{Enum.join(keys, ",")})
				VALUES
				#{Stream.map(lst, fn(_) -> "(?)" end) |> Enum.join(",")}
				ON DUPLICATE KEY UPDATE
				#{dupl};
				"""
				|> exec(Enum.map(lst, &(make_args(&1, keys))), pool)
		end
	end

	@spec make_args(simple_input, [simple_key]) :: [simple_val]
	defp make_args(map, keys) do
		Enum.map(keys,
			fn(k) ->
				case Map.has_key?(map, k) do
					true -> Map.get(map, k)
					false -> raise("#{__MODULE__ |> Atom.to_string} : no key #{inspect k} in struct #{inspect map}")
				end
			end)
	end

end
