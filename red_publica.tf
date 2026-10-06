resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}-internet"
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}-rutas-publicas"
  }
}

resource "aws_route" "salida_publica" {
  route_table_id         = aws_route_table.publica.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.principal.id
}

resource "aws_route_table_association" "publica" {
  for_each = {
    for nombre, subred in aws_subnet.red : nombre => subred
    if startswith(nombre, "publica_")
  }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.publica.id
}
