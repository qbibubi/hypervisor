RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function print_success() {
  echo -e "${GREEN}$1${NC}"
}

function print_error() {
  echo -e "${RED}$1${NC}"
}

function print_warning() {
  echo -e "${YELLOW}$1${NC}"
}

function print() {
  echo "$1"
}
