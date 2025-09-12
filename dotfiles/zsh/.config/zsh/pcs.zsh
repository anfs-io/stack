# shortcuts for pcs functions

pcs-adopt() {
  wget -qO- https://raw.githubusercontent.com/maxcole/pcs-bootstrap/refs/heads/main/adopt.sh | sudo bash -s -- all
}

pcs-control() {
  wget -qO- https://raw.githubusercontent.com/maxcole/pcs-bootstrap/refs/heads/main/controller.sh | bash -s -- all
}
