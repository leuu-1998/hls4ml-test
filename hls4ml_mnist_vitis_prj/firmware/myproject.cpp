#include <iostream>

#include "myproject.h"
#include "parameters.h"

void myproject(
    input_t conv2d_1_input[N_INPUT_1_1*N_INPUT_2_1*N_INPUT_3_1],
    result_t layer12_out[N_LAYER_11]
) {

    // hls-fpga-machine-learning insert IO
    #pragma HLS ARRAY_RESHAPE variable=conv2d_1_input complete dim=0
    #pragma HLS ARRAY_PARTITION variable=layer12_out complete dim=0
    #pragma HLS INTERFACE ap_vld port=conv2d_1_input,layer12_out 
    #pragma HLS DATAFLOW 

#ifndef __SYNTHESIS__
    static bool loaded_weights = false;
    if (!loaded_weights) {
        // hls-fpga-machine-learning insert load weights
        nnet::load_weights_from_txt<conv2d_1_weight_t, 72>(w2, "w2.txt");
        nnet::load_weights_from_txt<conv2d_1_bias_t, 8>(b2, "b2.txt");
        nnet::load_weights_from_txt<conv2d_2_weight_t, 1152>(w5, "w5.txt");
        nnet::load_weights_from_txt<conv2d_2_bias_t, 16>(b5, "b5.txt");
        nnet::load_weights_from_txt<dense_1_weight_t, 12800>(w9, "w9.txt");
        nnet::load_weights_from_txt<dense_1_bias_t, 32>(b9, "b9.txt");
        nnet::load_weights_from_txt<dense_2_weight_t, 320>(w11, "w11.txt");
        nnet::load_weights_from_txt<dense_2_bias_t, 10>(b11, "b11.txt");
        loaded_weights = true;
    }
#endif

    // ****************************************
    // NETWORK INSTANTIATION
    // ****************************************

    // hls-fpga-machine-learning insert layers

    layer2_t layer2_out[OUT_HEIGHT_2*OUT_WIDTH_2*N_FILT_2];
    #pragma HLS ARRAY_PARTITION variable=layer2_out complete dim=0
    nnet::conv_2d_cl<input_t, layer2_t, config2>(conv2d_1_input, layer2_out, w2, b2); // conv2d_1

    layer3_t layer3_out[OUT_HEIGHT_2*OUT_WIDTH_2*N_FILT_2];
    #pragma HLS ARRAY_PARTITION variable=layer3_out complete dim=0
    nnet::relu<layer2_t, layer3_t, relu_config3>(layer2_out, layer3_out); // conv2d_1_relu

    layer4_t layer4_out[OUT_HEIGHT_4*OUT_WIDTH_4*N_FILT_4];
    #pragma HLS ARRAY_PARTITION variable=layer4_out complete dim=0
    nnet::pooling2d_cl<layer3_t, layer4_t, config4>(layer3_out, layer4_out); // max_pooling2d_1

    layer5_t layer5_out[OUT_HEIGHT_5*OUT_WIDTH_5*N_FILT_5];
    #pragma HLS ARRAY_PARTITION variable=layer5_out complete dim=0
    nnet::conv_2d_cl<layer4_t, layer5_t, config5>(layer4_out, layer5_out, w5, b5); // conv2d_2

    layer6_t layer6_out[OUT_HEIGHT_5*OUT_WIDTH_5*N_FILT_5];
    #pragma HLS ARRAY_PARTITION variable=layer6_out complete dim=0
    nnet::relu<layer5_t, layer6_t, relu_config6>(layer5_out, layer6_out); // conv2d_2_relu

    layer7_t layer7_out[OUT_HEIGHT_7*OUT_WIDTH_7*N_FILT_7];
    #pragma HLS ARRAY_PARTITION variable=layer7_out complete dim=0
    nnet::pooling2d_cl<layer6_t, layer7_t, config7>(layer6_out, layer7_out); // max_pooling2d_2

    auto& layer8_out = layer7_out;
    layer9_t layer9_out[N_LAYER_9];
    #pragma HLS ARRAY_PARTITION variable=layer9_out complete dim=0
    nnet::dense<layer7_t, layer9_t, config9>(layer8_out, layer9_out, w9, b9); // dense_1

    layer10_t layer10_out[N_LAYER_9];
    #pragma HLS ARRAY_PARTITION variable=layer10_out complete dim=0
    nnet::relu<layer9_t, layer10_t, relu_config10>(layer9_out, layer10_out); // dense_1_relu

    layer11_t layer11_out[N_LAYER_11];
    #pragma HLS ARRAY_PARTITION variable=layer11_out complete dim=0
    nnet::dense<layer10_t, layer11_t, config11>(layer10_out, layer11_out, w11, b11); // dense_2

    nnet::softmax<layer11_t, result_t, softmax_config12>(layer11_out, layer12_out); // dense_2_softmax

}
