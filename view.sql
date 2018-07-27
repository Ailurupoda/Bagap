---------------------------------------------------------------
--Corentin FALCONE - 07/2018
--Fichier répertoriant les vues de la base de données
---------------------------------------------------------------

--/\**********************************************************/\
--************************************************************
--								VIEWS
--************************************************************
--/\**********************************************************/\

--*********************************************************
--1/ Vue matérialisée listant les zones avec la géométrie globale
--*********************************************************
	--Materialized view contour des zones
Drop materialized view mv_zone;
CREATE materialized view mv_zone as
	(Select 'zone_a' as zone_id,
		st_union(tA) as _zone_geom
	From (select array_agg(surf_geom) as tA From surface where surf_code like 'A%') as tta
	)
	UNION
	(Select 'zone_c' as zone_id,
		st_union(tC) as zone_geom
	From (select array_agg(surf_geom) as tC From surface where surf_code like 'C%') as ttc
	)
	UNION 
	(Select 'zone_b' as zone_id,
		st_union(tB) as zone_geom
	From (select array_agg(surf_geom) as tB From surface where surf_code like 'B%') as ttb
	)
;

--*********************************************************
--2/ Informationd es session pour afficher les données sans les id
--*********************************************************
	--Récupération des données session
Create Or Replace view v_mod_session as
	Select 
		ses_id,
		date,
		o.nom,
		o.prenom,
		e.etat
	From public.session 
	INNER JOIN public.etat_session e on e.etses_id = ses_etat
	LEFT Join public.observateur o on o.obs_id = ses_observateur
	ORDER BY date desc;

--*********************************************************
--3/ Information des bordures pour affiche les données sans les id
--*********************************************************
	--Récupération des données bordure
Create Or Replace view v_mod_bordure as
Select
	bor_id,
	lis_code,
	surf_code
From public.bordure
INNER JOIN public.lisiere on lis_id = bor_lisiere
INNER JOIN public.surface on surf_id = bor_surf
;

--*********************************************************
--4/ Observations des bordures actuelle lorsqu'éxistante, par défaut sinon
--*********************************************************
	--Observation_bordure courante 
		--Valeurs false lorsque les données ne sont pas connues
CREATE OR REPLACE VIEW public.v_observation_bordure AS 
 	SELECT 
	 	COALESCE(ob.obsbrd_id, NULL::integer) AS vobs_id,
	    bordure.bor_id,
	    bordure.bor_code,
	    bordure.bor_geom,
	    ob.warning,
	    ob.commentaires,
	    COALESCE(ob.abatt, false) AS abatt,
	    COALESCE(ob.tet_emon, false) AS tet_emon,
	    COALESCE(ob.cepee_cou, false) AS cepee_cou,
	    COALESCE(ob.rago_emon, false) AS rago_emon,
	    COALESCE(ob.epara_bran, false) AS epara_bran,
	    COALESCE(ob.epar_arbus, false) AS epar_arbus,
	    COALESCE(ob.elag_lamier, false) AS elag_lamier,
	    COALESCE(ob.emonde_hai, false) AS emonde_hai,
	    COALESCE(ob.coup_branc, false) AS coup_branc,
	    COALESCE(ob.ent_coupel, false) AS ent_coupel,
	    COALESCE(ob.bali_cepee, false) AS bali_cepee,
	    COALESCE(ob.ha_aba_bal, false) AS ha_aba_bal,
	    COALESCE(ob.ha_abattue, false) AS ha_abattue,
	    COALESCE(ob.arbu_arrac, false) AS arbu_arrac,
	    COALESCE(ob.arb_cou_cl, false) AS arb_cou_cl,
	    COALESCE(ob.plantation, false) AS plantation,
	    COALESCE(ob.arbu_coupe, false) AS arbu_coupe,
	    COALESCE(ob.paturage, false) AS paturage,
	    COALESCE(ob.patu_piet, false) AS patu_piet,
	    COALESCE(ob.fa_ss_arbu, false) AS fa_ss_arbu,
	    COALESCE(ob.fauche, false) AS fauche,
	    COALESCE(ob.broyage, false) AS broyage,
	    COALESCE(ob.brulis, false) AS brulis,
	    COALESCE(ob.debroussai, false) AS debroussai,
	    COALESCE(ob.labour, false) AS labour,
	    COALESCE(ob.talus_degr, false) AS talus_degr,
	    COALESCE(ob.fa_ss_clot, false) AS fa_ss_clot,
	    COALESCE(ob.nb_arbu_coup, '-1'::integer) AS nb_arbu_coup,
	    COALESCE(ob.talus_aras, false) AS talus_aras,
	    COALESCE(ob.id_session, func_curr_session()) AS id_session
	   FROM bordure
			LEFT JOIN ( SELECT ob_1.obsbrd_id,
	            ob_1.obs_id_bordure,
	            ob_1.warning,
	            ob_1.commentaires,
	            ob_1.abatt,
	            ob_1.tet_emon,
	            ob_1.cepee_cou,
	            ob_1.rago_emon,
	            ob_1.epara_bran,
	            ob_1.epar_arbus,
	            ob_1.elag_lamier,
	            ob_1.emonde_hai,
	            ob_1.coup_branc,
	            ob_1.ent_coupel,
	            ob_1.bali_cepee,
	            ob_1.ha_aba_bal,
	            ob_1.ha_abattue,
	            ob_1.arbu_arrac,
	            ob_1.arb_cou_cl,
	            ob_1.plantation,
	            ob_1.arbu_coupe,
	            ob_1.paturage,
	            ob_1.patu_piet,
	            ob_1.fa_ss_arbu,
	            ob_1.fauche,
	            ob_1.broyage,
	            ob_1.brulis,
	            ob_1.debroussai,
	            ob_1.labour,
	            ob_1.talus_degr,
	            ob_1.fa_ss_clot,
	            ob_1.nb_arbu_coup,
	            ob_1.talus_aras,
	            ob_1.id_session
	           	FROM observation_bordure ob_1
	            INNER JOIN session ON session.ses_id = ob_1.id_session
	        	WHERE session.ses_etat = 1 OR session.ses_etat = 2 OR session.ses_etat = 3) ob 
			ON ob.obs_id_bordure = bordure.bor_id
		Where bor_actif;
		ORDER BY bordure.bor_code
;

--*********************************************************
--5/ Observation des bordures totales
--*********************************************************
  --Observation_bordure total
CREATE OR REPLACE VIEW public.v_observation_bordure_tot AS 
	SELECT 
	 	ROW_NUMBER() OVER() as unique_id,
	 	COALESCE(ob.obsbrd_id, NULL::integer) AS vobs_id,
	    bordure.bor_id,
	    bordure.bor_code,
	    bordure.bor_geom,
	    ob.warning,
	    ob.commentaires,
	    ob.abatt AS abatt,
	    ob.tet_emon AS tet_emon,
	    ob.cepee_cou AS cepee_cou,
	    ob.rago_emon AS rago_emon,
	    ob.epara_bran AS epara_bran,
	    ob.epar_arbus AS epar_arbus,
	    ob.elag_lamier AS elag_lamier,
	    ob.emonde_hai AS emonde_hai,
	    ob.coup_branc AS coup_branc,
	    ob.ent_coupel AS ent_coupel,
	    ob.bali_cepee AS bali_cepee,
	    ob.ha_aba_bal AS ha_aba_bal,
	    ob.ha_abattue AS ha_abattue,
	    ob.arbu_arrac AS arbu_arrac,
	    ob.arb_cou_cl AS arb_cou_cl,
	    ob.plantation AS plantation,
	    ob.arbu_coupe AS arbu_coupe,
	    ob.paturage AS paturage,
	    ob.patu_piet AS patu_piet,
	    ob.fa_ss_arbu AS fa_ss_arbu,
	    ob.fauche AS fauche,
	    ob.broyage AS broyage,
	    ob.brulis AS brulis,
	    ob.debroussai AS debroussai,
	    ob.labour AS labour,
	    ob.talus_degr AS talus_degr,
	    ob.fa_ss_clot AS fa_ss_clot,
	    ob.nb_arbu_coup AS nb_arbu_coup,
	    ob.talus_aras AS talus_aras,
	    ob.id_session AS id_session,
	    ob.date
	   	FROM bordure
	 	LEFT JOIN ( SELECT ob_1.obsbrd_id,
	            ob_1.obs_id_bordure,
	            ob_1.warning,
	            ob_1.commentaires,
	            ob_1.abatt,
	            ob_1.tet_emon,
	            ob_1.cepee_cou,
	            ob_1.rago_emon,
	            ob_1.epara_bran,
	            ob_1.epar_arbus,
	            ob_1.elag_lamier,
	            ob_1.emonde_hai,
	            ob_1.coup_branc,
	            ob_1.ent_coupel,
	            ob_1.bali_cepee,
	            ob_1.ha_aba_bal,
	            ob_1.ha_abattue,
	            ob_1.arbu_arrac,
	            ob_1.arb_cou_cl,
	            ob_1.plantation,
	            ob_1.arbu_coupe,
	            ob_1.paturage,
	            ob_1.patu_piet,
	            ob_1.fa_ss_arbu,
	            ob_1.fauche,
	            ob_1.broyage,
	            ob_1.brulis,
	            ob_1.debroussai,
	            ob_1.labour,
	            ob_1.talus_degr,
	            ob_1.fa_ss_clot,
	            ob_1.nb_arbu_coup,
	            ob_1.talus_aras,
	            ob_1.id_session,
	            date
	           	FROM observation_bordure ob_1
		   		INNER JOIN session ON session.ses_id = ob_1.id_session) ob 
		ON ob.obs_id_bordure = bordure.bor_id
		Where bor_actif
;

--*********************************************************
--6/ Observation des surface actuelles où de la dernière session
--*********************************************************
  --Observation surface courante
  	--Valeurs courantes ou précédentes (si !courante)
CREATE OR REPLACE VIEW v_observation_surface AS
	Select 
		ROW_NUMBER() OVER() as unique_id,
		os.obsurf_id as vobs_id,
		surf_code, 
		surf_id, 
		surf_geom, 
		coalesce(os.hauteur, old_os.hauteur) hauteur, 
		coalesce(os.commentaires, old_os.commentaires) commentaires, 
		coalesce(os.warning, old_os.warning) warning, 
		coalesce(os.id_session, old_os.id_session) id_session, 
		coalesce(os.code_etat_surface, old_os.code_etat_surface) code_etat_surface, 
		coalesce(os.code_utilisation_sol,old_os.code_utilisation_sol) code_utilisation_sol
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
	Where surf_actif
	AND not exists (Select hf_surf_id From histo_fusion Where hf_surf_id = surf_id
;


--*********************************************************
--7/ Observation des surfaces totales
--*********************************************************
	--Observation_surface total
CREATE OR REPLACE VIEW v_observation_surface_tot AS
	Select 
		ROW_NUMBER() OVER() as unique_id,
		os.obsurf_id as vobs_id,
		surf_code, 
		surf_id, 
		surf_geom, 
		os.hauteur hauteur, 
		os.commentaires commentaires, 
		os.warning warning, 
		os.id_session id_session, 
		os.code_etat_surface code_etat_surface,
		os.etat etat_surface, 
		os.code_utilisation_sol code_utilisation_sol,
		os.utilisation utilisation,
		os.occcupation_sol occupation_sol
	From surface
	LEFT JOIN (select obs_id_surface, hauteur, os.warning, os.commentaires, id_session, code_etat_surface, etat, code_utilisation_sol, utilisation, occcupation_sol , obsurf_id, date
			From observation_surface os
			INNER JOIN session on ses_id = id_session
			INNER JOIN etat_surface es on es.code = code_etat_surface
			INNER JOIN utilisation_sol us on us.code = code_utilisation_sol 
	) os
	on surf_id = os.obs_id_surface
	Where surf_actif)
;

--*********************************************************
--8/ Observation des des parcelles fusionnées actuelle ou de la dernière session
--*********************************************************
	--Observation des parcelles fusionnées
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


--*********************************************************
--5/ Vue matérialisée des parcelles fusionnées 
--*********************************************************
	--Vue matérialisée récupérant la geom union des fusions
Create materialized view mv_fusion_surface as
	Select 
		hf_surf_ref,
		st_union(surf_geom) as surf_geom
	From histo_fusion, surface
	Where st_intersects(hf_geom, surf_geom)
	Group by hf_surf_ref;
