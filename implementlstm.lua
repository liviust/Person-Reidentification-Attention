require 'nn'
require 'nngraph'
require 'utilities.lua'
local LSTM = {}
function LSTM.lstm(input_size, rnn_size, n, dropout)
  dropout = dropout or 0.5
  -- there will be 2*n+1 inputs
  local inputs = {}
 
  table.insert(inputs, nn.Identity()():annotate{name='Identity'}) -- indices giving the sequence of symbols
  for L = 1,n do
    table.insert(inputs, nn.Identity()()) -- prev_c[L]
    table.insert(inputs, nn.Identity()()) -- prev_h[L]
  end
  table.insert(inputs,nn.Identity()():annotate{name='conv_feat_map'})
  local x, input_size_L
  local outputs = {inputs[4]}
  for L = 1,n do
    -- c,h from previos timesteps
    local prev_h = inputs[L*2+1]
    local prev_c = inputs[L*2]
    -- the input to this layer
    if L == 1 then
      x = inputs[1]
      --x = nn.BatchNormalization(input_size)(x)
      input_size_L = input_size
    else 
      x = outputs[(L-1)*2] 
      if dropout > 0 then x = nn.Dropout(dropout)(x):annotate{name='drop_' .. L} end -- apply dropout, if any
      input_size_L = rnn_size
    end
    -- evaluate the input sums at once for efficiency
    local i2h = nn.Linear(input_size_L, 4 * rnn_size)(x):annotate{name='i2h_'..L}
    local h2h = nn.Linear(rnn_size, 4 * rnn_size)(prev_h):annotate{name='h2h_'..L}
    local all_input_sums = nn.CAddTable()({i2h, h2h})

    local reshaped = nn.Reshape(4, rnn_size)(all_input_sums)
    local n1, n2, n3, n4 = nn.SplitTable(2)(reshaped):split(4)
    -- decode the gates
    local in_gate = nn.Sigmoid()(n1)
    local forget_gate = nn.Sigmoid()(n2)
    local out_gate = nn.Sigmoid()(n3)
    -- decode the write inputs
    local in_transform = nn.Tanh()(n4)
    -- perform the LSTM update
    local next_c           = nn.CAddTable()({
        nn.CMulTable()({forget_gate, prev_c}),
        nn.CMulTable()({in_gate,     in_transform})
      })
    -- gated cells form the output
    local next_h = nn.CMulTable()({out_gate, nn.Tanh()(next_c)})
    local op     =nn.Linear(rnn_size,6*6)(next_h)
    local softmax=nn.SoftMax()(op)
    table.insert(outputs, next_c)
    table.insert(outputs, next_h)
    table.insert(outputs,softmax)

  end
  -- set up the decoder
  --local top_h = nn.Identity()(outputs[#outputs])

  --if dropout > 0 then top_h = nn.Dropout(dropout)(top_h):annotate{name='drop_final'} end
  --table.insert(outputs, top_h)
  print(inputs)
  return nn.gModule(inputs, outputs)
end
model=LSTM.lstm(5,5,1,0)

--print(model.forwardnodes[2].data.module)

params,gradparams=model:getParameters()
--print(params)

-- for k, v in ipairs(model.forwardnodes) do
-- 	--print('hello')
--     --if v.data.annotations.name == 'name' then
--     print(v)
--     --end
-- end

-- model = localizeMemory(model);
-- graph.dot(model.fg, 'model','test')  
-- print(model)
return LSTM
