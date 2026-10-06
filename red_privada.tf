locals {
  conexiones_privadas = {
    a = {
      publica = "publica_a"
      privada = "privada_a"
    }
    b = {
      publica = "publica_b"
      privada = "privada_b"
    }
  }
}

resource "aws_eip" "nat" {
  for_each = local.conexiones_privadas
  domain   = "vpc"

  tags = {
    Name = "${local.prefijo}-ip-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "salida" {
  for_each = local.conexiones_privadas

  allocation_id     = aws_eip.nat[each.key].id
  subnet_id         = aws_subnet.red[each.value.publica].id
  connectivity_type = "public"
  availability_mode = "zonal"

  tags = {
    Name = "${local.prefijo}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.principal, aws_route.salida_publica]
}

resource "aws_route_table" "privada" {
  for_each = local.conexiones_privadas
  vpc_id   = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}-rutas-privadas-${each.key}"
  }
}

resource "aws_route" "salida_privada" {
  for_each = local.conexiones_privadas

  route_table_id         = aws_route_table.privada[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.salida[each.key].id
}

resource "aws_route_table_association" "privada" {
  for_each = local.conexiones_privadas

  subnet_id      = aws_subnet.red[each.value.privada].id
  route_table_id = aws_route_table.privada[each.key].id
}
