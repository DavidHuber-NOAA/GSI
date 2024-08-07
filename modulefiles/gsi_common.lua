help([[
Load common modules to build GSI on all machines
]])

local netcdf_c_ver=os.getenv("netcdf_c_ver") or "4.9.2"
local netcdf_fortran_ver=os.getenv("netcdf_fortran_ver") or "4.6.1"

local bacio_ver=os.getenv("bacio_ver") or "2.4.1"
local w3emc_ver=os.getenv("w3emc_ver") or "2.10.0"
local sp_ver=os.getenv("sp_ver") or "2.5.0"
local ip_ver=os.getenv("ip_ver") or "4.3.0"
local sigio_ver=os.getenv("sigio_ver") or "2.3.2"
local sfcio_ver=os.getenv("sfcio_ver") or "1.4.1"
local nemsio_ver=os.getenv("nemsio_ver") or "2.5.4"
local wrf_io_ver=os.getenv("wrf_io_ver") or "1.2.0"
local ncio_ver=os.getenv("ncio_ver") or "1.1.2"
local crtm_ver=os.getenv("crtm_ver") or "2.4.0.1"
local ncdiag_ver=os.getenv("ncdiag_ver") or "1.1.2"

load(pathJoin("netcdf-c", netcdf_c_ver))
load(pathJoin("netcdf-fortran", netcdf_fortran_ver))

prepend_path("PATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/bin", ":")
prepend_path("LD_LIBRARY_PATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib64", ":")
prepend_path("DYLD_LIBRARY_PATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib64", ":")
prepend_path("CPATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/include", ":")
prepend_path("CMAKE_PREFIX_PATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/.", ":")
prepend_path("PATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/bin", ":")
prepend_path("CMAKE_PREFIX_PATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/.", ":")
prepend_path("PYTHONPATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib/python3.11/site-packages", ":")
setenv("BUFR_LIB4", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib64/libbufr_4.a")
setenv("BUFR_INC4", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/include/bufr_4")
prepend_path("PYTHONPATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib64/python3.11/site-packages", ":")
prepend_path("PYTHONPATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib64/python3.11/site-packages", ":")
prepend_path("PYTHONPATH", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install/lib64/python3.11/site-packages", ":")
setenv("bufr_ROOT", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install")
setenv("BUFR_ROOT", "/work/noaa/global/dhuber/LIBS/bufr_12.1.0_hercules_keep/install")
load(pathJoin("bacio", bacio_ver))
load(pathJoin("w3emc", w3emc_ver))
load(pathJoin("sp", sp_ver))
load(pathJoin("ip", ip_ver))
load(pathJoin("sigio", sigio_ver))
load(pathJoin("sfcio", sfcio_ver))
load(pathJoin("nemsio", nemsio_ver))
load(pathJoin("wrf-io", wrf_io_ver))
load(pathJoin("ncio", ncio_ver))
load(pathJoin("crtm", crtm_ver))
load(pathJoin("gsi-ncdiag",ncdiag_ver))
