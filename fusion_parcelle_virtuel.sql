Create table histo_fusion ( --Table répertoriant les parcelles à fusionner pour le terrain
	hf_id serial,
	hf_geom geometry(point, 2154),
	hf_num_union integer default (fun_num_fusion()),
	hf_date date DEFAULT current_date,
	hf_surf_id integer,--Id de la surface concernée
	hf_surf_ref integer,--Id de la surface référence
	Constraint pk_histo_fusion Primary Key (hf_id)
);

Create or Replace Function fun_num_fusion()
	Returns integer AS
--Fonction servant de valeur par défaut pour la fusion des parcelles
$BODY$
	Declare
		num integer;
	Begin
		Select max(hf_num_union)
			From histo_fusion
		Into num;

		Return num;
	END;
$BODY$
	LANGUAGE 'plpgsql';


Create or Replace Function fun_tri_intersect_fusion()--Fonction trigger d'insertion des parcelles dans les fusion et rafraichissement de la VM
	Returns trigger AS
$BODY$
	Declare
		v_surf integer;
		v_surf_ref integer;
	Begin
		IF TG_OP = 'INSERT' THEN
			IF NEW.hf_surf_id IS NULL THEN
				Select hf_surf_ref
					From histo_fusion
					Where hf_num_union = NEW.hf_num_union
					LIMIT 1
				INTO v_surf_ref;
				IF v_surf_ref IS NULL THEN
					Select surf_id
						From surface, histo_fusion 
						Where st_intersects(NEW.hf_geom, surf_geom)
					INTO v_surf_ref;
				END IF;
				Select surf_id
					From surface, histo_fusion 
					Where st_intersects(NEW.hf_geom, surf_geom)
				INTO v_surf;
				UPDATE histo_fusion
					Set 
						hf_surf_id = v_surf,
						hf_surf_ref = v_surf_ref
					Where NEW.hf_id = hf_id;
			END IF;
		ELSIF TG_OP = 'UPDATE' THEN
			IF NEW.hf_geom = OLD.hf_geom IS NULL THEN
				Select hf_surf_ref
					From histo_fusion
					Where hf_num_union = NEW.hf_num_union
					LIMIT 1
				INTO v_surf_ref;
				IF v_surf_ref IS NULL THEN
					Select surf_id
						From surface, histo_fusion 
						Where st_intersects(NEW.hf_geom, surf_geom)
					INTO v_surf_ref;
				END IF;
				Select surf_id
					From surface, histo_fusion 
					Where st_intersects(NEW.hf_geom, surf_geom)
				INTO v_surf;
				UPDATE histo_fusion
					Set 
						hf_surf_id = v_surf,
						hf_surf_ref = v_surf_ref
					Where NEW.hf_id = hf_id;
			END IF;				
		END IF;
		REFRESH MATERIALIZED VIEW mv_fusion_surface;
		Return NEW;
		
	END;
$BODY$
	LANGUAGE 'plpgsql';

drop trigger tri_surface_fusion on histo_fusion;

Create trigger tri_surface_fusion 
	AFTER Insert or Update on public.histo_fusion
	FOR EACH ROW EXECUTE Procedure fun_tri_intersect_fusion();


CREATE OR REPLACE VIEW v_observation_fusion AS
	Select 
		ROW_NUMBER() OVER() as unique_id,
		os.obsurf_id as vobs_id,
		surf_code, 
		surf_id, 
		fus.surf_geom, 
		coalesce(os.hauteur, old_os.hauteur) hauteur, 
		coalesce(os.commentaires, old_os.commentaires) commentaires, 
		coalesce(os.warning, old_os.warning) warning, 
		coalesce(os.id_session, old_os.id_session) id_session, 
		coalesce(os.code_etat_surface, old_os.code_etat_surface) code_etat_surface, 
		coalesce(os.code_utilisation_sol,old_os.code_utilisation_sol) code_utilisation_sol,
		hf_surf_ref
	From surface
	LEFT JOIN (select obs_id_surface, hauteur, os.warning, os.commentaires, id_session, code_etat_surface, code_utilisation_sol , obsurf_id
			From observation_surface os
			INNER JOIN session on ses_id = id_session 
			Where ses_etat = '1' or ses_etat = '2' or ses_etat = '3') os
	on surf_id = os.obs_id_surface 
	LEFT JOIN (select obs_id_surface, hauteur, os.warning, os.commentaires, id_session, code_etat_surface, code_utilisation_sol , obsurf_id
			From observation_surface os
			INNER JOIN session on ses_id = id_session 
			Where ses_etat = '4' ) old_os
	on surf_id = old_os.obs_id_surface
	INNER JOIN mv_fusion_surface fus ON hf_surf_ref = surf_id;




Create materialized view mv_fusion_surface as--VM répertoriant les parcelles fusionnées
	Select 
		hf_surf_ref,
		st_union(surf_geom) as surf_geom
	From histo_fusion, surface
	Where st_intersects(hf_geom, surf_geom)
	Group by hf_surf_ref;
	

Create or Replace function fun_tri_obs_fusion()
	Returns trigger AS
$body$
	Declare
		s public.surface.surf_id%type; --Id surfaces parcourue
	Begin
		IF (TG_OP = 'UPDATE') THEN
			--Cas UDPATE
			RAISE NOTICE '%', TG_OP;
			IF NEW.vobs_id IS NULL OR NEW.vobs_id = 0 THEN
				--Cas inexistant (INSERT)
				For s in Select hf_surf_id From histo_fusion Where hf_surf_ref = OLD.hf_surf_ref LOOP
					INSERT INTO public.observation_surface(warning, 
															commentaires, 
															hauteur
	,														code_etat_surface,
															code_utilisation_sol,
															obs_id_surface,
															id_session)
					VALUES
						(NEW.warning, 
							NEW.commentaires, 
							NEW.hauteur,
							NEW.code_etat_surface,
							NEW.code_utilisation_sol,
							s,
							NEW.id_session);
				END LOOP;

					RETURN NEW;
			ELSE
				--Cas existant (UPDATE)
				For s in Select hf_surf_id From histo_fusion Where hf_surf_ref = OLD.hf_surf_ref LOOP
					UPDATE observation_surface
						SET warning = NEW.warning, 
							commentaires = NEW.commentaires, 
							hauteur = NEW.hauteur,
							code_etat_surface = NEW.code_etat_surface,
							code_utilisation_sol = NEW.code_utilisation_sol,
							id_session = NEW.id_session
					WHERE obs_id_surface = s AND id_session = NEW.id_session;
				END LOOP;
				RETURN NEW;
			END IF;

	   	ELSIF (TG_OP = 'DELETE') THEN
	   		--Cas DELETE
	   		For s in Select hf_surf_id From histo_fusion Where hf_surf_ref = OLD.hf_surf_ref LOOP
				DELETE FROM observation_surface where obs_id_surface = s AND id_session = OLD.id_session;
			END LOOP;
			RETURN OLD;
	   	END IF;
	   	RETURN NEW;
	End;
$body$
	LANGUAGE 'plpgsql';

Create trigger tri_surface_fusion 
INSTEAD of Update Or Delete on public.v_observation_fusion
FOR EACH ROW EXECUTE Procedure fun_tri_obs_fusion();