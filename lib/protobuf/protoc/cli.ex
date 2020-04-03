defmodule Protobuf.Protoc.CLI do
  @moduledoc """
  protoc plugin for generating Elixir code

  See `protoc -h` and protobuf-elixir for details.
  NOTICE: protoc-gen-elixir(this name is important) must be in $PATH

  ## Examples

      $ protoc --elixir_out=./lib your.proto
      $ protoc --elixir_out=plugins=grpc:./lib/ *.proto
      $ protoc -I protos --elixir_out=./lib protos/namespace/*.proto

  Options:
  * --version       Print version of protobuf-elixir
  * --help          Print this help
  """

  alias Protobuf.Protoc.TypeMetadata

  @doc false
  def main(["--version"]) do
    {:ok, version} = :application.get_key(:protobuf, :vsn)
    IO.puts(to_string(version))
  end

  def main([opt]) when opt in ["--help", "-h"] do
    IO.puts(@moduledoc)
  end

  def main(_) do
    # https://groups.google.com/forum/#!topic/elixir-lang-talk/T5enez_BBTI
    :io.setopts(:standard_io, encoding: :latin1)
    bin = IO.binread(:all)
    request = Protobuf.Decoder.decode(bin, Google.Protobuf.Compiler.CodeGeneratorRequest)

    # debug
    # raise inspect(request, limit: :infinity)

    ctx =
      %Protobuf.Protoc.Context{}
      |> parse_params(request.parameter)
      |> find_types(request.proto_file)

    files =
      request.proto_file
      |> Enum.filter(fn desc -> Enum.member?(request.file_to_generate, desc.name) end)
      |> Enum.map(fn desc -> Protobuf.Protoc.Generator.generate(ctx, desc) end)

    response = Google.Protobuf.Compiler.CodeGeneratorResponse.new(file: files)
    IO.binwrite(Protobuf.Encoder.encode(response))
  end

  @doc false
  def parse_params(ctx, params_str) when is_binary(params_str) do
    params = String.split(params_str, ",")
    parse_params(ctx, params)
  end

  def parse_params(ctx, ["plugins=" <> plugins | t]) do
    plugins = String.split(plugins, "+")
    ctx = %{ctx | plugins: plugins}
    parse_params(ctx, t)
  end

  def parse_params(ctx, ["gen_descriptors=true" | t]) do
    ctx = %{ctx | gen_descriptors?: true}
    parse_params(ctx, t)
  end

  def parse_params(ctx, ["using_value_wrappers=true" | t]) do
    ctx = %{ctx | using_value_wrappers?: true}
    parse_params(ctx, t)
  end

  def parse_params(ctx, _), do: ctx

  @doc false
  def find_types(ctx, descs) do
    find_types(ctx, descs, %{})
  end

  @doc false
  def find_types(ctx, [], acc), do: %{ctx | global_type_mapping: acc}

  def find_types(ctx, [desc | t], acc) do
    types = find_types_in_proto(ctx, desc)
    find_types(ctx, t, Map.put(acc, desc.name, types))
  end

  @doc false
  def find_types_in_proto(
        %Protobuf.Protoc.Context{} = ctx,
        %Google.Protobuf.FileDescriptorProto{} = desc
      ) do
    ctx =
      %Protobuf.Protoc.Context{
        package: desc.package,
        namespace: [],
        using_value_wrappers?: ctx.using_value_wrappers?
      }
      |> Protobuf.Protoc.Context.cal_file_options(desc.options)

    %{}
    |> find_types_in_proto(ctx, desc.message_type)
    |> find_types_in_proto(ctx, desc.enum_type)
  end

  defp find_types_in_proto(types, ctx, descs) when is_list(descs) do
    Enum.reduce(descs, types, fn desc, acc ->
      find_types_in_proto(acc, ctx, desc)
    end)
  end

  defp find_types_in_proto(types, ctx, %Google.Protobuf.DescriptorProto{name: name} = desc) do
    new_ctx = append_ns(ctx, name)

    types
    |> update_types(ctx, desc)
    |> find_types_in_proto(new_ctx, desc.enum_type)
    |> find_types_in_proto(new_ctx, desc.nested_type)
  end

  defp find_types_in_proto(types, ctx, desc) do
    update_types(types, ctx, desc)
  end

  defp append_ns(%{namespace: ns} = ctx, name) do
    new_ns = ns ++ [name]
    Map.put(ctx, :namespace, new_ns)
  end

  defp update_types(types, %{namespace: ns, package: pkg, module_prefix: prefix} = ctx, desc) do
    name = desc.name
    module_name = gen_module_name(prefix, pkg, ns, name)
    type_metadata = type_metadata(ctx, desc, module_name)

    Map.put(types, Protobuf.Protoc.Generator.Util.pkg_name(ctx, name), type_metadata)
  end

  defp gen_module_name(prefix, pkg, ns, name) do
    (prefix || pkg)
    |> join_names(ns, name)
    |> Protobuf.Protoc.Generator.Util.normalize_type_name()
  end

  defp join_names(pkg, ns, name) do
    ns_str = Protobuf.Protoc.Generator.Util.join_name(ns)

    [pkg, ns_str, name]
    |> Enum.filter(&(&1 && &1 != ""))
    |> Enum.join(".")
  end

  defp get_msg_options(nil), do: %{}

  defp get_msg_options(options) do
    case Google.Protobuf.MessageOptions.get_extension(options, Elixirpb.PbExtension, :message) do
      nil ->
        %{}

      opts ->
        opts
    end
  end

  defp type_metadata(ctx, desc, module_name) do
    typespec = desc.options |> get_msg_options() |> Map.get(:typespec)

    case wrapper_type(ctx, desc) do
      {wrapper_type_name, scalar?} ->
        %TypeMetadata{
          type_name: wrapper_type_name || module_name,
          module_name: module_name,
          typespec: typespec,
          wrapper?: true,
          wrapper_target_scalar?: scalar?
        }

      nil ->
        %TypeMetadata{
          type_name: module_name,
          module_name: module_name,
          typespec: typespec
        }
    end
  end

  defp wrapper_type(ctx, %Google.Protobuf.DescriptorProto{} = desc) do
    with true <- ctx.using_value_wrappers?,
         {target_type_name, alias_target_name, scalar?} <- wrapper_target(ctx, desc.field),
         alias_wrapper_name when not is_nil(alias_wrapper_name) <- wrapper_name(desc.name),
         true <- String.downcase(alias_target_name) == String.downcase(alias_wrapper_name) do
      {target_type_name, scalar?}
    else
      _ -> nil
    end
  end

  defp wrapper_type(_ctx, %Google.Protobuf.EnumDescriptorProto{} = _desc), do: nil

  @wrapper_suffix "Value"
  @wrapper_suffix_size byte_size(@wrapper_suffix)
  defp wrapper_name(name) do
    name_size = byte_size(name)
    prefix_size = name_size - @wrapper_suffix_size

    case name do
      <<type_name::binary-size(prefix_size), @wrapper_suffix::binary>> -> type_name
      _ -> nil
    end
  end

  defp wrapper_target(%{namespace: ns, package: pkg, module_prefix: prefix} = _ctx, [
         %{name: "value", type_name: type_name, type: type} = _field
       ]) do
    cond do
      # NOTE: is_scalar
      is_nil(type_name) ->
        {type, to_string(Protobuf.TypeUtil.from_enum(type)), _scalar? = true}

      # NOTE: is_message_or_enum
      true ->
        alias_type_name = type_name |> String.split(".") |> List.last()
        elixir_type_name = gen_module_name(prefix, pkg, ns, alias_type_name)

        {elixir_type_name, alias_type_name, _scalar? = false}
    end
  end

  defp wrapper_target(_, _), do: nil
end
