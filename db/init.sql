-- bd existe
CREATE DATABASE IF NOT EXISTS bd_examen;
USE bd_examen;

-- venta
CREATE TABLE IF NOT EXISTS venta (
    id_venta BIGINT AUTO_INCREMENT PRIMARY KEY,
    direccion_compra VARCHAR(255) NOT NULL,
    valor_compra INT NOT NULL,
    fecha_compra DATE NOT NULL,
    despacho_generado BIT(1) NOT NULL DEFAULT b'0'
);

-- despacho
CREATE TABLE IF NOT EXISTS despacho (
    id_despacho BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha_despacho DATE,
    patente_camion VARCHAR(20),
    intento INT NOT NULL,
    id_compra BIGINT,
    direccion_compra VARCHAR(255),
    valor_compra BIGINT,
    despachado BIT(1) NOT NULL DEFAULT b'0'
);

-- datos de prueba
INSERT INTO venta (direccion_compra, valor_compra, fecha_compra, despacho_generado) VALUES 
('Av. Apoquindo 4500, Las Condes', 45000, '2026-05-15', b'1'),
('Calle Los Alerces 123, Ñuñoa', 12500, '2026-05-16', b'0'),
('Av. Providencia 1234, Santiago', 45900,  '2024-11-03', b'0'),
('Los Leones 876, Vitacura', 128500, '2024-11-10', b'0'),
('Gran Avenida 4521, San Miguel', 67300,  '2024-12-01', b'0'),
('Paseo Las Palmas 310, Las Condes', 89000,  '2025-01-15', b'0'),
('Camino Lo Barnechea 750, Lo Barnechea', 34200,  '2025-02-20', b'0'),
('Pasaje El Sol 89, San Miguel', 89990, '2026-05-17', b'1');

INSERT INTO despacho (fecha_despacho, patente_camion, intento, id_compra, direccion_compra, valor_compra, despachado) VALUES 
('2026-05-16', 'ABCD-12', 1, 1, 'Av. Apoquindo 4500, Las Condes', 45000, b'0'),
('2026-05-17', 'XYZW-34', 2, 3, 'Pasaje El Sol 89, San Miguel', 89990, b'1');
