# If you know that keyword list you will be using will be limited to 3–4 values,
# this is the faster lookup function vs. `Keyword.get` or `Access` (`kw_list[:key]`).
def kw_list_access(kw_list, key, default \\ nil) do
  case kw_list do
    [{h, v} | _] -> v
    [_, {h, v} | _] -> v
    [_, _, {h, v} | _] -> v
    [_, _, _, {h, v} | _] -> v
    _ -> Keyword.get(kw_list, key, default)
  end
end
