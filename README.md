# HLS4ML TESTS

## How to run jupyter in container

Create container (Via powershell terminal)

--rm: means that container will be deleted in the end of the session
-v: define de volumes, for work or for VITIS route

`docker run -it --rm -p 8888:8888 -v "${PWD}:/home/jovyan/work" quay.io/jupyter/pytorch-notebook:2024-10-22`

# tensorflow
`docker run -it --rm -p 8888:8888 -v "${PWD}:/tf/work" tensorflow/tensorflow:latest-jupyter`
