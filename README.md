# HLS4ML TESTS

## How to run jupyter in container

Create container (Via powershell terminal)

--rm: means that container will be deleted in the end of the session
-v: define de volumes, for work or for VITIS route

## Pytorch
`docker run -it --rm -p 8888:8888 -v "${PWD}:/home/jovyan/work" quay.io/jupyter/pytorch-notebook:2024-10-22`

## Tensorflow
`docker run -it --rm -p 8888:8888 -v "${PWD}:/tf/work" tensorflow/tensorflow:2.8.0-jupyter`

## Steps for this project

1. Create the model.
2. Generate HLS files and project using hls4ml library.
3. Generate the VITIS and VIVADO project to compile C++ and synthesize the RTL code.
4. Deploy on FPGA

## Scripts
Once you generate the dir with the HLS code, run the `create_vivado_project.tcl` script under the hls project path (if its from other dir, then change the route for IP).
To create the VITIS and VIVADO project and start compilation and syntesis. After that, create the file to integrate with Pynq.

1. VITIS project: `cd hls4ml_mnist_vitis_prj` and then `vitis_hls -f build_prj.tcl`
2. VIVADO project: `vivado -mode batch -source create_vivado_project.tcl`
