import { useState } from "react";
import { CardComponent } from "./CardComponent";
import { TableCompras } from "./TableCompras";
import { TableDespachos } from "./TableDespachos";

export const PruebaCards = () => {
  const [tablaCompras, setTablaCompras] = useState(false);
  const [tablaOrdenes, setTablaOrdenes] = useState(false);

  return (
    <section>
      <div className="flex justify-center">
        <CardComponent
          title="Consulta de compras"
          description="Revisa las últimas compras realizadas para generar su despacho"
          buttonText="Consultar"
          onClick={() => {
            setTablaCompras(true);
            setTablaOrdenes(false);
          }}
        />
        <CardComponent
          title="Consulta de despachos"
          description="Consulta los despachos realizados, modifica los registros de intentos o cierra la orden"
          buttonText="Consultar"
          onClick={() => {
            setTablaCompras(false);
            setTablaOrdenes(true);
          }}
        />
      </div>

      <section>
        {tablaCompras && <TableCompras />}
        {tablaOrdenes && <TableDespachos />}
      </section>
    </section>
  );
};
