# Build lipd_legacy.pkl exactly like fetch-pool does, but read the .lpd files
# in a fixed order (one file name per line in ORDER) instead of os.listdir order.
# Usage: python build_pkl.py <lpd_dir> <order_file> <out_pkl>
import os, pickle, sys
import lipd

lpd_dir, order_file, out_pkl = sys.argv[1:4]
order = [l.strip() for l in open(order_file) if l.strip()]
on_disk = sorted(f for f in os.listdir(lpd_dir) if f.endswith(".lpd"))
assert sorted(order) == on_disk, "order file does not match the .lpd files present"

_orig = lipd.list_files
def _ordered(x, path=""):
    if x == ".lpd" and path and os.path.abspath(path) == os.path.abspath(lpd_dir):
        return [os.path.join(path, f) for f in order]
    return _orig(x, path)
lipd.list_files = _ordered

D = lipd.readLipd(lpd_dir if lpd_dir.endswith("/") else lpd_dir + "/")
TS = lipd.extractTs(D)
with open(out_pkl, "wb") as f:
    pickle.dump({"D": D, "TS": TS}, f, protocol=2)
print(f"{os.path.basename(out_pkl)}: {len(D)} datasets, {len(TS)} timeseries")
