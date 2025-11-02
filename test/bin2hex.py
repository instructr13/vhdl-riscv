import sys

def print_usage():
  print(sys.argv[1])
  print("Usage:", sys.argv[0], "[bytes per line] [filename]")

  exit()

args = sys.argv[1:]

if len(args) != 2:
  print_usage()

BYTES_PER_LINE = None

try:
  BYTES_PER_LINE = int(args[0])
except:
  print_usage()

FILE_NAME = args[1]

allbytes = []

with open(FILE_NAME, "rb") as f:
  allbytes = f.read()

bytestrs = []

for b in allbytes:
  bytestrs.append(format(b, '02x'))

rem = len(bytestrs) % BYTES_PER_LINE
if rem != 0:
  bytestrs += ["00"] * (BYTES_PER_LINE - rem)
results = []

for i in range(0, len(bytestrs), BYTES_PER_LINE):
  s = ""

  for j in range(BYTES_PER_LINE):
    s += bytestrs[i + BYTES_PER_LINE - j - 1]

  results.append(s)

print("\n".join(results))

