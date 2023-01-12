help([[
]])

prepend_path("MODULEPATH", "/apps/hpc-stack/libs/hpc-stack/modulefiles/stack")

local hpc_ver=os.getenv("hpc_ver") or "1.2.0"
local hpc_intel_ver=os.getenv("hpc_intel_ver") or "2021.3.0"
local hpc_impi_ver=os.getenv("hpc_impi_ver") or "2021.3.0"
local intelpython_ver=os.getenv("intelpython_ver") or "2021.3.0"
local prod_util_ver=os.getenv("prod_util_ver") or "1.2.2"

load(pathJoin("hpc", hpc_ver))
load(pathJoin("hpc-intel", hpc_intel_ver))
load(pathJoin("hpc-impi", hpc_impi_ver))

load(pathJoin("intelpython", anaconda_ver))

load("gsi_common")

load(pathJoin("prod_util", prod_util_ver))

pushenv("CFLAGS", "-xHOST")
pushenv("FFLAGS", "-xHOST")

whatis("Description: GSI environment on GCP with Intel Compilers")
