# Docker Environment Design and Usage Guide (PodcastLLM Project)

## 1. Requirements

This project involves training large language models (LLMs) on a GPU-enabled machine, with the need for remote operation via SSH and future code handover. To ensure consistency, accelerate development, and improve reproducibility, the environment is built and managed using Docker container technology.

## 2. Benefits of Docker

### 2.1 Reproducibility & Consistency

Training LLMs typically requires numerous dependencies (specific versions of Python, PyTorch, CUDA, Transformers, etc.). Building these manually across different systems can lead to inconsistencies, conflicts, and errors. Docker enables packaging all runtime dependencies into a single image, ensuring uniform execution regardless of the host system.

### 2.2 Full GPU Integration (NVIDIA Support)

Docker integrates with the NVIDIA Container Toolkit to provide direct access to the host's GPU, achieving native-like performance. The container is capable of detecting the host's CUDA version and installing the matching PyTorch CUDA version accordingly.

### 2.3 Isolation from Host Environment

Docker containers run independently of the host OS, and any changes made within the container do not affect the host. This allows testing or using experimental dependencies without risk. Multiple container instances can be used to experiment with different environments or models without conflict.

### 2.4 Scripted and Transferable Environment

Docker environments are fully scripted via `Dockerfile` and `run.sh`, making them easily reproducible by other researchers. Configuration is documented within the scripts, supporting long-term version control and simplified onboarding.

### 2.5 Remote Operation with SSH and Automatic Mounting

After connecting to the host machine via SSH, users can start the Docker container using a single command (`./run.sh --start`). The script automatically mounts the project directory and VSCode Server cache, reducing setup effort and improving the remote development experience.

### 2.6 Flexible Version Control and Rollback

In the event of updates causing failures, users can revert to a previous image version or rebuild the environment to restore a stable setup. This is crucial for research workflows involving result comparisons over time.

## 3. Environment Structure and Explanation

### 3.1 Core Files

1. **Dockerfile**: Defines the base image (`nvidia/cuda:12.8.1-base-ubuntu20.04`), tools, users, and overall environment.
2. **run.sh**: Lifecycle management script for the container. Supports:
   - `--start`: Build and enter container
   - `--stop`: Stop and remove container
   - `--prune`: Remove both container and image
   - `--rebuild`: Rebuild the image and launch container
3. **start.sh**: Initialization script executed at container startup; installs appropriate PyTorch packages, configures directory permissions, and keeps the container running.

### 3.2 Volume Mounting

| Host Path                        | Container Path                      | Description                         |
|----------------------------------|-------------------------------------|-------------------------------------|
| `${PWD}/projects/`               | `/home/<user>/projects/`            | Project source code and output      |
| `${PWD}/temp/.vscode-server/`    | `/home/<user>/.vscode-server/`      | VSCode Server configuration & cache |

### 3.3 User and Permission Management

Upon container startup, a user matching the host's UID, GID, and username is created inside the container to maintain proper access control. This user has `sudo` privileges and avoids using root.

### 3.4 run.sh Script Behavior

`run.sh` is the main entry point for managing the development environment. It automates initialization and simplifies repeated container usage. Key behaviors include:

1. **Directory Preparation**: Ensures the presence of `projects/` and `temp/.vscode-server/` as mount points.
2. **Repository Auto-cloning**: Clones the PodcastLLM repo from GitHub if it does not yet exist locally.
3. **Image Build Automation**: Builds the Docker image with user-specific environment variables (UID, GID, username) if it does not already exist.
4. **GPU Detection & Enablement**: Checks GPU support and enables `--gpus all` accordingly.
5. **Container Execution & Mounting**: Mounts local folders into the container and uses a non-root user.
6. **Interactive Terminal Entry**: Automatically enters the container terminal post-launch.
7. **Command-Line Interface Options**: Supports `--start`, `--stop`, `--prune`, and `--rebuild` for comprehensive environment control.

### 3.5 Dockerfile Environment Construction

The `Dockerfile` defines the runtime environment with the following key elements:

1. **Base Image Selection**: Starts with `nvidia/cuda:12.8.1-base-ubuntu20.04` to ensure GPU compatibility.
2. **Development Tools Installation**: Includes essential tools such as Python, pip, Git, vim, wget, nano, and `nvidia-container-toolkit`. Also installs `cargo` and `ffmpeg` for LLM-related audio processing.
3. **User Setup**: Creates a user matching the host's UID/GID and grants `sudo` access for safety and consistency.
4. **Python Dependencies**: Installs required Python packages from `requirements.txt`.
5. **Localization**: Configures both `zh_TW.UTF-8` and `en_US.UTF-8` locales and sets the timezone to `Asia/Taipei`.
6. **Custom Initialization Scripts**: Copies `.bashrc`, `start.sh`, and a `startup` script to enable smooth startup configuration.
7. **Working Directory Setup**: Sets the default working directory to the user’s home and switches to the non-root user.

This setup ensures the resulting image is ready for use and aligned with both local and remote development needs.

### 3.6 start.sh Script Behavior

`start.sh` is the startup script executed within the container. Its role is to finalize the runtime environment by performing:

1. **GPU and CUDA Detection**: Detects if an NVIDIA GPU is available and determines the installed CUDA version.
2. **PyTorch Installation**: Based on the CUDA version, installs matching PyTorch, Torchvision, and Torchaudio builds. Defaults to CPU if GPU is unavailable.
3. **LLM Toolkit Installation**: Installs `sentence-transformers` for downstream tasks like embeddings and semantic search.
4. **Directory Permission Correction**: Fixes permissions for `.vscode-server/` and `projects/` to avoid access issues.
5. **Container Persistence**: Uses a tail command to keep the container alive after script execution.

This script ensures that each container session is bootstrapped with the correct packages and accessible development paths.

## 4. Usage Instructions

```bash
# Launch container (build image & clone repo if needed)
./run.sh --start

# Stop container
./run.sh --stop

# Remove container and image
./run.sh --prune

# Rebuild image and start container
./run.sh --rebuild
```

Once inside the container, you can start developing or training models immediately.

