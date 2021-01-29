/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * License); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * AS IS BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*
 * Copyright (c) 2021, OPEN AI LAB
 * Author: hhchen@openailab.com
 */


#include "cuda_executor.hpp"

extern "C"
{
#include "tengine_op.h"
#include "relu_param.h"
}

__global__ void relu(float *y, float *x, int N)
{
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (idx < N)
    {
        y[idx] = x[idx] > 0 ? x[idx] : 0;
    }
}

__global__ void leaky_relu(float *y, float *x, int N)
{
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (idx < N)
    {
        y[idx] = x[idx] > 0 ? x[idx] : x[idx] * 0.1;
    }
}

void relu_gpu_kernel(struct ir_graph* ir_graph, struct ir_node* ir_node, dict_uint2voidx  gpu_addr_map)
{
    struct ir_tensor* input_tensor = get_ir_graph_tensor(ir_graph, ir_node->input_tensors[0]);
    struct ir_tensor* output_tensor = get_ir_graph_tensor(ir_graph, ir_node->output_tensors[0]);

    /* init grid and block */
    int bs = 1024;
    int s = ceil((output_tensor->elem_num + bs - 1.) / bs);
    dim3 grid = dim3(s);

    struct relu_param* param = (struct relu_param*)ir_node->op.param_mem;

    if (0 == param->negative_slope)
        relu<<<grid, bs>>>((float*)gpu_addr_map[output_tensor->idx], (float*)gpu_addr_map[input_tensor->idx], output_tensor->elem_num);
    else
        leaky_relu<<<grid, bs>>>((float*)gpu_addr_map[output_tensor->idx], (float*)gpu_addr_map[input_tensor->idx], output_tensor->elem_num);
}

void CUDAEngine::AddReluNode(struct ir_graph* ir_graph, struct ir_node* ir_node)
{
    TLOG_INFO("Tengine GPU: Support OP(%d) OP_RELU.\n", ir_node->idx);
    relu_gpu_kernel(ir_graph, ir_node, this->gpu_addr_map);
    this->ops.push_back(std::bind(&relu_gpu_kernel, ir_graph, ir_node, this->gpu_addr_map));
}
