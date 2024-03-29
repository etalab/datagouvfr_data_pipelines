DO $$ 
BEGIN
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'stats_dvf' AND TABLE_SCHEMA = 'dvf') THEN
        TRUNCATE TABLE dvf.stats_dvf;
    ELSE
        CREATE UNLOGGED TABLE dvf.stats_dvf (
            code_geo VARCHAR(20),
            nb_ventes_maison INT,
            moy_prix_m2_maison INT,
            med_prix_m2_maison INT,
            nb_ventes_appartement INT,
            moy_prix_m2_appartement INT,
            med_prix_m2_appartement INT,
            nb_ventes_local INT,
            moy_prix_m2_local INT,
            med_prix_m2_local INT,
            nb_ventes_apt_maison INT,
            moy_prix_m2_apt_maison INT,
            med_prix_m2_apt_maison INT,
            annee_mois VARCHAR(7),
            libelle_geo VARCHAR(100),
            code_parent VARCHAR(10),
            echelle_geo VARCHAR(15)
        );
        /* PRIMARY KEY (echelle_geo, code_geo, annee_mois, code_parent)); */
        CREATE INDEX echelle_geo_idx ON stats_dvf USING btree (echelle_geo);
        CREATE INDEX code_geo_idx ON stats_dvf USING btree (code_geo);
        CREATE INDEX code_parent_idx ON stats_dvf USING btree (code_parent);
    END IF;
END $$;