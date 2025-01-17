help([[
]])

prepend_path("MODULEPATH", "/apps/ops/test/spack-stack-1.6.0-nco/envs/nco-intel-19.1.3.304/install/modulefiles/Core")

local stack_python_ver=os.getenv("python_ver") or "3.10.13"
local stack_intel_ver=os.getenv("stack_intel_ver") or "19.1.3.304"
local stack_cray_mpich_ver=os.getenv("stack_cray_mpich_ver") or "8.1.9"
local cmake_ver=os.getenv("cmake_ver") or "3.23.1"
local prod_util_ver=os.getenv("prod_util_ver") or "2.0.10"

load(pathJoin("stack-intel", stack_intel_ver))
load(pathJoin("stack-cray-mpich", stack_cray_mpich_ver))
load(pathJoin("stack-python", stack_python_ver))
-- BUFR is 12.0.1 in this version of spack-stack
pushenv("bufr_ver", "12.0.1")
load("gsi_common")
load(pathJoin("prod_util", prod_util_ver))
load(pathJoin("cmake", cmake_ver))

pushenv("CRTM_FIX", "/apps/ops/prod/libs/intel/19.1.3.304/crtm/2.4.0.1/fix")

unsetenv("CFLAGS")
unsetenv("CXXFLAGS")
unsetenv("FFLAGS")

pushenv("GSI_BINARY_SOURCE_DIR", "/lfs/h2/emc/global/noscrub/emc.global/FIX/fix/gsi/20241022")

whatis("Description: GSI environment on WCOSS2")
