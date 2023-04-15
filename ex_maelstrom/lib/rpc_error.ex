defmodule ExMaelstrom.RpcErrorCodes do
  @moduledoc false

  @type t :: %__MODULE__{
          time_out: integer(),
          not_supported: integer(),
          temporary_unavailable: integer(),
          malformed_request: integer(),
          crash: integer(),
          abort: integer(),
          key_doesnot_exist: integer(),
          key_already_exist: integer(),
          precondition_failed: integer(),
          txn_conflict: integer()
        }

  defstruct(
    time_out: 0,
    not_supported: 10,
    temporary_unavailable: 11,
    malformed_request: 12,
    crash: 13,
    abort: 14,
    key_doesnot_exist: 20,
    key_already_exist: 21,
    precondition_failed: 22,
    txn_conflict: 30
  )

  @spec new() :: __MODULE__.t()
  def new() do
    %__MODULE__{
      time_out: 0,
      not_supported: 10,
      temporary_unavailable: 11,
      malformed_request: 12,
      crash: 13,
      abort: 14,
      key_doesnot_exist: 20,
      key_already_exist: 21,
      precondition_failed: 22,
      txn_conflict: 30
    }
  end
end

defmodule ExMaelstrom.RpcError do
  @moduledoc false

  # TODO module doc

  @type t :: %__MODULE__{
          code: integer(),
          text: String.t(),
          type: String.t()
        }

  defstruct(
    code: nil,
    text: "",
    type: "error"
  )

  # TODO doc
  @spec new_rpc_error(code :: integer(), text: String.t()) :: __MODULE__.t()
  def new_rpc_error(code, text) do
    __MODULE__.__struct__(
      code: code,
      text: text
    )
  end
end
