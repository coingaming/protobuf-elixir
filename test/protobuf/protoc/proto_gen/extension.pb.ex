defmodule Protobuf.Protoc.ExtTest.Month do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  @type t :: integer | :UNKNOWN | :JANUARY

  field :UNKNOWN, 1
  field :JANUARY, 2
end

defmodule Protobuf.Protoc.ExtTest.Foo do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          a: String.t(),
          month: Protobuf.Protoc.ExtTest.Month.t() | nil
        }
  defstruct a: nil, month: nil

  field :a, 1, optional: true, type: :string
  field :month, 2, optional: true, type: Protobuf.Protoc.ExtTest.MonthValue
end

defmodule Protobuf.Protoc.ExtTest.MonthValue do
  @moduledoc false
  use Protobuf, syntax: :proto2, wrapper?: true

  @type t :: %__MODULE__{
          value: Protobuf.Protoc.ExtTest.Month.t()
        }
  defstruct value: nil

  field :value, 1, optional: true, type: Protobuf.Protoc.ExtTest.Month, enum: true
end

defmodule Protobuf.Protoc.ExtTest.Enum do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          value: String.t()
        }
  defstruct value: nil

  field :value, 1, optional: true, type: :string
end

defmodule Protobuf.Protoc.ExtTest.UnixDateTime do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          microseconds: integer
        }
  defstruct microseconds: nil

  field :microseconds, 1, required: true, type: :int64
end

defmodule Protobuf.Protoc.ExtTest.FooWithUnixDateTime do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          inserted_at: DateTime.t() | nil
        }
  defstruct inserted_at: nil

  field :inserted_at, 1, optional: true, type: Protobuf.Protoc.ExtTest.UnixDateTime
end
