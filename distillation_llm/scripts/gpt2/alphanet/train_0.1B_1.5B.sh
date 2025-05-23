#! /bin/bash

MASTER_ADDR=localhost
MASTER_PORT=${2-2012}
NNODES=1
NODE_RANK=0
GPUS_PER_NODE=${3-4}

START_ALPHA_BETA=${4-1.0}  # alpha_beta 起始值
END_ALPHA_BETA=${5-1.0}    # alpha_beta 终止值
START_ALPHA=${6-0.5}  # alpha 起始值
END_ALPHA=${7-0.5}    # alpha 终止值

DISTRIBUTED_ARGS="--nproc_per_node $GPUS_PER_NODE \
                  --nnodes $NNODES \
                  --node_rank $NODE_RANK \
                  --master_addr $MASTER_ADDR \
                  --master_port $MASTER_PORT"

# model
BASE_PATH=${1-"./"}
CKPT_NAME="gpt2-base/714"
CKPT="${BASE_PATH}/results/gpt2/train/init/${CKPT_NAME}"
TEACHER_CKPT_NAME="xlarge-sft"
TEACHER_CKPT="${BASE_PATH}/results/gpt2/train/sft/gpt2-xlarge/"
# data
DATA_DIR="${BASE_PATH}/processed_data/dolly/full/gpt2/"
#LM_DATA_DIR="${BASE_PATH}/processed_data/openwebtext/gpt2/512/10M/"
LM_DATA_DIR="${BASE_PATH}/processed_data/openwebtext/"
# hp
BATCH_SIZE=8
LR=0.0005
GRAD_ACC=1
EVAL_BATCH_SIZE=64
# length
MAX_LENGTH=512
# seed
SEED=10


OPTS=""
# model
OPTS+=" --base-path ${BASE_PATH}"
OPTS+=" --model-path ${CKPT}"
OPTS+=" --teacher-model-path ${TEACHER_CKPT}"
OPTS+=" --ckpt-name ${CKPT_NAME}"
OPTS+=" --teacher-ckpt-name ${TEACHER_CKPT_NAME}"
OPTS+=" --teacher-model-fp16"
OPTS+=" --n-gpu ${GPUS_PER_NODE}"
# data
OPTS+=" --data-dir ${DATA_DIR}"
OPTS+=" --lm-data-dir ${LM_DATA_DIR}"
OPTS+=" --num-workers 4"
OPTS+=" --dev-num 1000"
# hp
OPTS+=" --lr ${LR}"
OPTS+=" --batch-size ${BATCH_SIZE}"
OPTS+=" --eval-batch-size ${EVAL_BATCH_SIZE}"
OPTS+=" --gradient-accumulation-steps ${GRAD_ACC}"
OPTS+=" --warmup-iters 0"
OPTS+=" --lr-decay-style cosine"
OPTS+=" --weight-decay 1e-2"
OPTS+=" --clip-grad 1.0"
OPTS+=" --epochs 20"
OPTS+=" --kd-ratio 1.0"
# length
OPTS+=" --max-length ${MAX_LENGTH}"
OPTS+=" --max-prompt-length 256"
# runtime
OPTS+=" --do-train"
OPTS+=" --do-valid"
OPTS+=" --eval-gen"
OPTS+=" --save-interval -1"
OPTS+=" --eval-interval -1"
OPTS+=" --log-interval 4"
OPTS+=" --mid-log-num -1"
# seed
OPTS+=" --seed ${SEED}"
# deepspeed
OPTS+=" --deepspeed"
OPTS+=" --deepspeed_config ${BASE_PATH}/configs/deepspeed/ds_config.json"
# type
OPTS+=" --type alphanet"
# gen
OPTS+=" --do-sample"
OPTS+=" --top-k 0"
OPTS+=" --top-p 1.0"
OPTS+=" --temperature 1.0"
# distillm
OPTS+=" --student-gen"
OPTS+=" --gen-num-beams 1"
OPTS+=" --gen-top-p 1.0"
OPTS+=" --init-threshold 0.0"
OPTS+=" --loss-eps 0.1"
OPTS+=" --capacity 1000"


export NCCL_DEBUG=""
export WANDB_DISABLED=True
export TF_CPP_MIN_LOG_LEVEL=3
export PYTHONPATH=${BASE_PATH}
export CUDA_VISIBLE_DEVICES=1,2,3,5

for alpha in 0.1 0.2 0.3 ; do
    for beta in 0.9 0.8 0.7; do
#        beta=$(echo "$alpha_beta - $alpha" | bc)
        # runtime
#        if [[ ( "$alpha" == "1" && "$beta" == "0" ) || \
#              ( "$alpha" == "0" && "$beta" == "1" ) || \
#              ( "$alpha" == "0.5" && "$beta" == "0.5" ) || \
#              ( "$alpha" == "0.2" && "$beta" == "0.7" ) ]]; then
#            continue
#        fi

        SAVE_PATH="${BASE_PATH}/results/gpt2/train/alphanet/distill_0.1B_0.7B_no-adaptive-/${alpha}_${beta}"
        mkdir -p ${SAVE_PATH}

        CURRENT_OPTS="${OPTS}"
        CURRENT_OPTS+=" --save ${SAVE_PATH}"
        CURRENT_OPTS+=" --ab_alpha ${alpha}"
        CURRENT_OPTS+=" --ab_beta ${beta}"

        CMD="torchrun ${DISTRIBUTED_ARGS} ${BASE_PATH}/finetune.py ${CURRENT_OPTS} $@"
        echo ${CMD}
        echo "PYTHONPATH=${PYTHONPATH}"
        CODE_BASE=HF
        ${CMD}
    done
done

#for alpha_beta in $(seq ${START_ALPHA_BETA} 0.1 ${END_ALPHA_BETA}); do
#    for alpha in $(seq ${START_ALPHA} 0.1 ${END_ALPHA}); do
#        beta=$(echo "$alpha_beta - $alpha" | bc)
#        # runtime
#        SAVE_PATH="${BASE_PATH}/results/gpt2/train/ab/distill_0.1B_1.5B_final_no-adaptive-/${alpha}_${beta}"
#        mkdir -p ${SAVE_PATH}
#
#        CURRENT_OPTS="${OPTS}"
#        CURRENT_OPTS+=" --save ${SAVE_PATH}"
#        CURRENT_OPTS+=" --ab_alpha ${alpha}"
#        CURRENT_OPTS+=" --ab_beta ${beta}"
#
#        CMD="torchrun ${DISTRIBUTED_ARGS} ${BASE_PATH}/finetune.py ${CURRENT_OPTS} $@"
#        echo ${CMD}
#        echo "PYTHONPATH=${PYTHONPATH}"
#        CODE_BASE=HF
#        ${CMD}
#    done
#done
# bash scripts/gpt2/sft/sft_medium.sh ./ 2012 4
# bash scripts/gpt2/ab/train_0.1B_1.5B.sh ./ 2012 4 0 0 0 0

