CREATE OR REPLACE FUNCTION public.func_temp_bordure_tri(p_bordure integer)
	RETURNS integer AS

$BODY$
	DECLARE
		b public.bordure%rowtype;--Variable récupérant les données de la table bordure
		bL1 public.lisiere.lis_id%TYPE;--Variable récupérant l'id des lisières qui sont proche
		surf1 public.surface.surf_id%TYPE;--Variable récupérant l'id des surface dans lesquelles les lisières sont proche
		bufferFin integer;-- Valeur du buffer à réaliser
		bufferDebut integer;-- Valeur par défaut du buffer si il n'est pas modifié
		nb integer; -- Nombre de MAJ réalisée
		d1 double precision;--distance la plus courte entre 2 lisières
		d2 double precision;--Distance entre deux lisière par rapport au centroïd L1
		d3 double precision;--Distance entre deux lisière par rapport au centroïd L2
		d4 double precision;--Distance au centroïd des deux lisières
	BEGIN
		bufferDebut = 10;--Buffer initialisé à 10m
		nb = 0;--Nombre de mise à jour à 0

		Select * 
			From public.bordure 
			where bor_id = p_bordure
		INTO b;
		For bL1, surf1, d1, d2, d3, d4 in Select l1.lis_id, s.surf_id, st_distance((l1.lis_geom), (l2.lis_geom)) as dist, st_distance(st_centroid(l1.lis_geom), (l2.lis_geom)), st_distance(st_centroid(l2.lis_geom), (l1.lis_geom)), st_distance(st_centroid(l2.lis_geom), st_centroid(l1.lis_geom))
										From lisiere l1, lisiere l2, surface s
										Where l1.lis_id != l2.lis_id
										AND st_length(st_intersection(l1.lis_geom, s.surf_geom)) > 5
										AND st_length(st_intersection(l2.lis_geom, s.surf_geom)) > 5
										AND (st_distance(l1.lis_geom, l2.lis_geom) > 0 OR (st_distance (st_centroid(l1.lis_geom), l2.lis_geom) <5 OR st_distance(st_centroid(l2.lis_geom), l1.lis_geom) <5))
										AND st_distance(l1.lis_geom, l2.lis_geom) <5
										ORDER by l1.lis_code, l2.lis_code, surf_code 
		LOOP--Parcours des lisières étroites
				IF b.bor_lisiere = bL1 AND b.bor_surf = surf1 THEN
					--Calcul de la taille du buffer lorsque les lisières sont étroites
					IF d1 > 0 THEN
						IF (d2 < 20 OR d3 < 20 )THEN
							-- Distance validée, récupération de d1 pour buffer
							bufferFin = d1/2;
						END IF;
					ELSE
						--Recherche de la plus petite distance
						IF d2 < d3 AND d2 < d4 THEN
							bufferFin = d2/2;
						ELSIF d3 < d2 AND d3 < d4 THEN
							bufferFin = d3/2;
						ELSE
							bufferFin = d4/2;
						END IF;
					END IF;
					EXIT;
				ELSE 
					--La bordure n'est pas issue d'une lisière étroite
					bufferFin = bufferDebut;
				END IF;
		END LOOP;
				--Mise à jours de la géométrie de la bordure avec un buffer flat
		UPDATE bordure 
			Set bor_geom = (Select st_intersection(st_buffer(l.lis_geom, bufferFin, 'endcap=flat'), s.surf_geom)
							From bordure
							Join surface s on surf_id = bor_surf
							Join lisiere l on lis_id = bor_lisiere
							Where bor_id = b.bor_id)
			Where bor_id = b.bor_id;	
		RETURN 1;
	END;
$BODY$
	LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.func_repare_bordure_tri(p_bordure integer)
	RETURNS integer AS
$BODY$
	DECLARE
		b public.bordure%rowtype;--Variable récupérant les données de la table bordure
		b2 public.bordure%rowtype; -- Variable récupérant les données de la table bordure à comparer 
		nb integer;--Variable comptant le nombre de mise à jour réalisées à retourner
	BEGIN
		nb = 0;--Initialisation à 0
		Select *
			From public.bordure
			Where bor_id = p_bordure
		INTO b;
			For b2 in Select * From public.bordure LOOP -- On compare toutes les données de la table bordure
				IF b.bor_id != b2.bor_id and st_overlaps(b.bor_geom, b2.bor_geom) THEN -- Si les bordures se superposent
					--Recherche de la plus petite bordure pour la soustraire à la plus grande
					IF st_area(b.bor_geom) > st_area(b2.bor_geom) THEN
						UPDATE public.bordure set bor_geom = st_difference(b.bor_geom, b2.bor_geom) Where bor_geom = b.bor_geom;
							--Mise à jour de la bordure en enlevant le morceau de la deuxième
						nb = nb+1;
					ELSE
						UPDATE public.bordure set bor_geom = st_difference(b2.bor_geom, b.bor_geom) Where bor_geom = b2.bor_geom;
						nb = nb +1;
					END IF;
					--Mise à jour de la table en supprimant une partie de la première géométrie
				END IF;
			
			END LOOP;
		RETURN 1;
	END;
$BODY$
	LANGUAGE plpgsql VOLATILE;



CREATE OR REPLACE function public.func_maj_bordure_tri()
	RETURNS trigger AS
$BODY$
	BEGIN
		IF (NEW.bor_lisiere != OLD.bor_lisiere ) OR (NEW.bor_surf != OLD.bor_surf) THEN
			PERFORM func_temp_bordure_tri(NEW.bor_id);
			PERFORM func_repare_bordure_tri(NEW.bor_id);
		END IF;

		RETURN NULL;
	END;
$BODY$
	LANGUAGE plpgsql;

CREATE Trigger tri_update_bordure
	AFTER INSERT or UPDATE 
	ON public.bordure
	FOR EACH ROW 
	EXECUTE Procedure func_maj_bordure_tri();
