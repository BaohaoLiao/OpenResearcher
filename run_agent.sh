#!/bin/bash
# Quick start script for running agent with multiple vLLM servers
# Usage: ./run_agent.sh [output_dir] [base_port] [num_servers] [dataset_name] [browser_backend] [model_path]

OUTPUT_DIR=${1:-"results/browsecomp_plus/OpenResearcher_dense"}
BASE_PORT=${2:-8001}
NUM_SERVERS=${3:-2}
DATASET_NAME=${4:-"browsecomp_plus"}
BROWSER_BACKEND=${5:-"local"}
MODEL=${6:-"OpenResearcher/OpenResearcher-30B-A3B"}
MAX_ROUNDS=${MAX_ROUNDS:-200}


SEARCH_URL="http://localhost:8000"

# Get script directory (project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAIN_REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
EVAL_ENV_DIR="${MAIN_REPO_ROOT}/.eval"
LOCAL_ENV_DIR="${SCRIPT_DIR}/.venv"
cd "$SCRIPT_DIR"

if [ -f "${EVAL_ENV_DIR}/bin/activate" ]; then
    ENV_DIR="${EVAL_ENV_DIR}"
elif [ -f "${LOCAL_ENV_DIR}/bin/activate" ]; then
    ENV_DIR="${LOCAL_ENV_DIR}"
else
    echo "Error: No evaluation environment found." >&2
    echo "Run ${MAIN_REPO_ROOT}/install_scripts/setup_eval_env.sh or ${SCRIPT_DIR}/setup.sh" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${ENV_DIR}/bin/activate"
PYTHON_BIN="${ENV_DIR}/bin/python"

# Build comma-separated server URLs
SERVER_URLS=""
for i in $(seq 0 $((NUM_SERVERS-1))); do
    PORT=$((BASE_PORT + i))
    URL="http://localhost:${PORT}/v1"

    if [ -n "$SERVER_URLS" ]; then
        SERVER_URLS="${SERVER_URLS},${URL}"
    else
        SERVER_URLS="${URL}"
    fi
done

echo "=========================================="
echo "Starting Agent with Multiple vLLM Servers"
echo "=========================================="
echo "Model: $MODEL"
echo "Number of Servers: $NUM_SERVERS"
echo "Server URLs:"
for i in $(seq 0 $((NUM_SERVERS-1))); do
    PORT=$((BASE_PORT + i))
    echo "  - http://localhost:${PORT}/v1"
done
echo "Search Service: $SEARCH_URL"
echo "Dataset: $DATASET_NAME"
echo "Browser Backend: $BROWSER_BACKEND"
echo "Output Directory: $OUTPUT_DIR"
echo "Max Rounds: $MAX_ROUNDS"
echo "=========================================="
echo ""

# Check if using browsecomp-plus dataset (needs local data path)
if [ "$DATASET_NAME" = "browsecomp_plus" ]; then
    DATA_PATH="${SCRIPT_DIR}/Tevatron/browsecomp-plus/data/*.parquet"
    echo "Using local BrowseComp-Plus dataset: $DATA_PATH"
    echo ""

    "${PYTHON_BIN}" deploy_agent.py \
        --output_dir "$OUTPUT_DIR" \
        --model_name_or_path "$MODEL" \
        --search_url "$SEARCH_URL" \
        --dataset_name "$DATASET_NAME" \
        --data_path "$DATA_PATH" \
        --browser_backend "$BROWSER_BACKEND" \
        --reasoning_effort high \
        --vllm_server_url "$SERVER_URLS" \
        --max_rounds "$MAX_ROUNDS" \
        --max_concurrency_per_worker 32
else
    # HuggingFace datasets or OpenAI BrowseComp (no local data_path needed)
    echo "Using dataset: $DATASET_NAME"
    echo "Available datasets: browsecomp, gaia, xbench"
    echo ""

    "${PYTHON_BIN}" deploy_agent.py \
        --output_dir "$OUTPUT_DIR" \
        --model_name_or_path "$MODEL" \
        --search_url "$SEARCH_URL" \
        --dataset_name "$DATASET_NAME" \
        --browser_backend "$BROWSER_BACKEND" \
        --reasoning_effort high \
        --vllm_server_url "$SERVER_URLS" \
        --max_rounds "$MAX_ROUNDS" \
        --max_concurrency_per_worker 32
fi
