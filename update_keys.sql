
--*************************************************************************************--
-- Fichier répertoriant les manipulations de la base pour la mettre en état de marche  --
--*************************************************************************************--



--*************************************************************************
--Suppression des tables 
--*************************************************************************
/*Drop Table IF EXISTS public.observation_bordure Cascade;
Drop Table IF EXISTS public.etat_session Cascade;
Drop Table IF EXISTS public.etat_surface Cascade;
Drop Table IF EXISTS public.lisiere Cascade;
Drop Table IF EXISTS public.observateur Cascade;
Drop Table IF EXISTS public.observation_surface Cascade;
Drop Table IF EXISTS public.session Cascade;
Drop Table IF EXISTS public.surface Cascade;
Drop Table IF EXISTS public.utilisation_sol Cascade;
Drop Table IF EXISTS public.bordure Cascade;
*/



--*************************************************************************
--Ajout des clés primaire serial | Création des "clés-code"
--*************************************************************************
	--Bordure
Alter Table public.bordure rename column id to bor_code; --L'ancien ID devient un code
Alter Table public.bordure add column bor_id serial;--Nouvel ID

	--Etat_session
Alter Table public.etat_session add column etses_id serial;--Ajout d'un ID etat session

	--lisiere
Alter Table public.lisiere rename column id to lis_code;--L'ancien ID devient un code
Alter Table public.lisiere add column lis_id serial;--Nouvel ID

	--obervateur
Alter Table public.observateur rename column id to obs_code;--L'ancien ID devient un code
Alter Table public.observateur add column obs_id serial;--Nouvel ID

	--observation_bordure
Alter Table public.observation_bordure rename column id to obsbrd_code;--L'ancien ID devient un code
Alter Table public.observation_bordure add column obsbrd_id serial;--Nouvel ID

	--observation_surface
Alter Table public.observation_surface rename column id to obsurf_code;--L'ancien ID devient un code
Alter Table public.observation_surface add column obsurf_id serial;--Nouvel ID

	--surface
Alter Table public.surface rename column id to surf_code;--L'ancien ID devient un code
Alter Table public.surface add column surf_id serial;--Nouvel ID


--*************************************************************************
--Ajout des clés étrangères integer
--*************************************************************************
	--Observation_bordure
Alter Table public.observation_bordure add column obs_id_bordure integer;--Ajout de la référence à la bordure

	--Bordure
Alter Table public.bordure add column bor_surf integer;--Ajout de la référence à la surface
Alter Table public.bordure add column bor_lisiere integer;--Ajout de la référence à la lisière

	--Session
Alter Table public.session add column ses_etat integer;--Ajout de la référence à l'état
Alter Table public.session add column ses_observateur integer;--Ajout de la référence à l'observateur
Alter Table public.session rename column etat to code_etat;--Transformation de l'état en code

	--Observation_surface
Alter Table public.observation_surface add column obs_id_surface integer;--Ajout de la référence à la surface


--*************************************************************************
--Modification des champs identiques entre table
--*************************************************************************
ALTER TABLE public.lisiere rename column geom to lis_geom;

ALTER TABLE public.surface rename column geom to surf_geom;

ALTER TABLE public.session rename column id to ses_id;


--*************************************************************************
--Insertion des données "copies" : Transformation des CODES en ID
--*************************************************************************
	--Bordure
Update public.bordure
	Set bor_surf = (Select surf_id 
						From public.surface
						Where surf_code = id_surface), -- Récupération des identifiants ID correspondant aux codes
		bor_lisiere = (Select lis_id
							From public.lisiere
							Where lis_code = id_lisiere);-- Récupération des identifiants ID correspondant aux codes

Update public.observation_bordure
	Set obs_id_bordure = (Select bor_id
							From public.bordure
							Where id_bordure = bor_code);-- Récupération des identifiants ID correspondant aux codes

Update public.session 
	Set ses_etat = (Select etses_id
						From public.etat_session
						Where code_etat = etat),-- Récupération des identifiants ID correspondant à l'état
		ses_observateur = (Select obs_id
							From public.observateur
							Where obs_code = id_observateur);-- Récupération des identifiants ID correspondant aux codes


--*************************************************************************
--Modification clés primaires / étrangères
--*************************************************************************
	--Suppression des contraintes étrangères (Référence aux CODE)
		--Bordure
Alter Table public.bordure drop constraint if exists lisiere_2_bordure;--Suppression de la contrainte sur le CODE lisiere
Alter Table public.bordure drop constraint if exists parcelle_2_bordure;--Suppression de la contrainte sur le CODE surface

Alter Table public.session drop constraint if exists etat_2_session; --Suppression de la contrainte sur l'Etat
		
		--Observation_bordure
Alter Table public.observation_bordure drop constraint if exists bordure_2_observation_bordure;--Suppression de la contrainte sur le CODE bordure

	--Suppression des contraintes primaires (sur CODE)
Alter Table public.lisiere drop constraint if exists lisiere_pkey;--Lisiere

Alter Table public.surface drop constraint if exists parcelle_pkey;--Surface

Alter Table public.bordure drop constraint if exists bordure_pkey;--Bordure

Alter Table public.observation_bordure drop constraint if exists observation_bordure_pkey;--Observation_bordure

Alter Table public.observation_surface drop constraint if exists observation_parcelle_pkey;--Observation_surface

Alter Table public.observateur drop constraint if exists observateur_pkey;--Observateur

Alter Table public.etat_session drop constraint if exists etat_session_pkey;--Etat session

	--Ajout clé primaires (sur ID)
Alter Table public.lisiere add constraint pk_lisiere Primary Key (lis_id);--Lisiere

Alter Table public.surface add constraint pk_parcelle Primary Key (surf_id);--Surface

Alter Table public.bordure add constraint pk_bordure Primary Key (bor_id);--Bordure

Alter Table public.observation_bordure add constraint pk_observation_bordure Primary Key (obsbrd_id);--Observation_bordure

Alter Table public.observation_surface add constraint pk_observation_surface Primary Key (obsurf_id);--Observation_surface	

Alter Table public.observateur add constraint pk_observateur Primary Key (obs_id);--Observateur

Alter Table public.etat_session add constraint pk_etat_session Primary Key (etses_id);--Etat_session

	--Création des clés étrangères (Référence aux ID)
		--Bordure
Alter Table public.bordure add constraint fk_lisiere_2_bordure 
	Foreign Key (bor_lisiere) References public.lisiere (lis_id);--Bordure --> Lisiere
Alter Table public.bordure add constraint fk_parcelle_2_bordure 
	Foreign Key (bor_surf) References public.surface (surf_id);--Bordure --> Surface

Alter Table public.observation_bordure add constraint fk_bordure_2_observation_bordure
	Foreign Key (obs_id_bordure) References public.bordure (bor_id);--Observation_bordure --> Bordure

Alter Table public.observation_surface add constraint fk_surface_2_observation_surface
	Foreign Key (obs_id_surface) References public.surface(surf_id);--Observation_surface --> Surface

Alter Table public.session add constraint fk_observateur_2_session
	Foreign Key (ses_observateur) References public.observateur(obs_id);--Session --> Obervateur
Alter Table public.session add constraint fk_etat_2_session
	Foreign Key (ses_etat) References public.etat_session(etses_id);--Session --> Etat

--*************************************************************************
--Suppression des champs anciens étrangères
--*************************************************************************
	--Observation_bordure
Alter Table public.observation_bordure drop column if exists id_bordure;--Suppression de la référence CODE
Alter Table public.observation_bordure drop column if exists obsbrd_code; --Suppression de l'ancienne clé primaire
	
	--Bordure
Alter Table public.bordure drop column if exists id_surface;--Suppression de la référence CODE
Alter Table public.bordure drop column if exists id_lisiere;--Suppression de la référence CODE

	--Session
Alter Table public.session drop column if exists code_etat;--Suppression de la référence CODE
Alter Table public.session drop column if exists id_observateur;--Suppression de la référence CODE

	--Observation_surface
Alter Table public.observation_surface drop column if exists obsurf_code;--Suppression de l'ancienne clé primaire


--*************************************************************************
--Ajout de la géométrie de la bordure
--*************************************************************************
	--Ajout de la colonne géométrie de la bordure
Alter Table public.bordure Add Column bor_geom geometry(geometry, 2154);

	--Création de la fonction attribuant la géométrie de la bordure
/*CREATE OR REPLACE FUNCTION public.func_geom_bordure()
  RETURNS integer AS
$BODY$
DECLARE
		b1 public.bordure%ROWTYPE;
    BEGIN
    	FOR b1 in select * from bordure LOOP
	        UPDATE public.bordure set bor_geom =  
	        	(Select st_intersection(st_buffer(l.geom, 15), s.geom) 
	    --Création d'une entité intersectée entre le buffer de la lisière (de la bordure )de 4m et la surface (de la bordure)
					From public.bordure b
					Join public.lisiere l on l.lis_id = b.bor_lisiere
					Join public.surface s on s.surf_id = b.bor_surf
					and b.bor_id = b1.bor_id
			)
	       	Where bor_id = b1.bor_id;
		END LOOP;
        RETURN 1;
    END;
$BODY$
	LANGUAGE plpgsql VOLATILE;

	--Lancement de la fonction d'attribution de la géométrie bordure
Select func_geom_bordure();*/

--********************************************
--Création des index
--********************************************

/*CREATE INDEX indx_borudre_geom
	ON public.bordure
	USING gist
	(bor_geom);*/
CREATE INDEX indx_bordure_fk
	ON public.bordure
	USING btree
	(bor_surf, bor_lisiere);
CREATE INDEX indx_bordure_code
	ON public.bordure
	USING btree
	(bor_code);


/*CREATE INDEX indx_surface_geom
	ON public.surface
	USING gist
	(geom);*/
CREATE INDEX indx_surface_code
	ON public.surface
	USING btree
	(surf_code);


/*CREATE INDEX indx_lisiere_geom
	ON public.lisiere
	USING gist
	(geom);*/
CREATE INDEX indx_lisiere_code
	ON public.lisiere
	USING btree
	(lis_code);


CREATE INDEX indx_observation_surface_fk
	ON public.observation_surface
	USING btree
	(obs_id_surface);
/*CREATE INDEX indx_observation_surface_session
	ON public.observation_surface
	USING btree
	(id_session);*/
	

CREATE INDEX indx_observation_bordure_fk
	ON public.observation_bordure
	USING btree
	(obs_id_bordure);
CREATE INDEX indx_observation_bordure_session
	ON public.observation_bordure
	USING btree
	(id_session);


--*************************************************************************
-- Ajout de contrainte de clé unique
--*************************************************************************
Alter table observation_bordure add constraint uq_bord_session UNIQUE (id_session, obs_id_bordure);

Alter table observation_surface add constraint uq_surf_session UNIQUE (id_session, obs_id_surface);

--*************************************************************************
--Gestion des valeurs par défaut issues de selection
--*************************************************************************
	--Fonction récupérant l'identifiant de la session courante
Create Or Replace Function func_curr_session() 
	Returns integer AS 
$BODY$
	DECLARE 
		sesID public.session.ses_id%TYPE;
	BEGIN
		sesID = (Select ses_id 
					From public.session
					Join public.etat_session ON etses_id = ses_etat
					Where etat in ('en cours', 'créée') LIMIT 1);
		RETURN sesID;
	END;
$BODY$
	LANGUAGE 'plpgsql';
					
	-- Affectation de la fonction en valeur par defaut sur observation_bordure et observation_surface
ALTER TABLE public.observation_surface ALTER COLUMN id_session SET DEFAULT (func_curr_session());
ALTER TABLE public.observation_bordure ALTER COLUMN id_session SET DEFAULT (func_curr_session());

--/\**********************************************************/\
--************************************************************
--								VIEWS
--************************************************************
--/\**********************************************************/\

	--Récupération des données session
Create Or Replace view v_mod_session as
Select 
	ses_id,
	date,
	o.nom,
	o.prenom,
	e.etat
From public.session 
Join public.etat_session e on e.etses_id = ses_etat
LEFT Join public.observateur o on o.obs_id = ses_observateur
ORDER BY date desc;

	--Récupération des données bordure
Create Or Replace view v_mod_bordure as
Select
	bor_id,
	lis_code,
	surf_code
From public.bordure
Join public.lisiere on lis_id = bor_lisiere
Join public.surface on surf_id = bor_surf;

	--Observation_bordure courante 
		--Valeurs par défaut lorsque les données ne sont pas connues)
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
             JOIN session ON session.ses_id = ob_1.id_session
          WHERE session.ses_etat = 1 OR session.ses_etat = 2 OR session.ses_etat = 3) ob ON ob.obs_id_bordure = bordure.bor_id
  ORDER BY bordure.bor_code;

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
	   JOIN session ON session.ses_id = ob_1.id_session) ob ON ob.obs_id_bordure = bordure.bor_id;


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
		Join session on ses_id = id_session 
		Where ses_etat = '1' or ses_etat = '2' or ses_etat = '3') os
on surf_id = os.obs_id_surface 
LEFT JOIN (select obs_id_surface, hauteur, os.warning, os.commentaires, id_session, code_etat_surface, code_utilisation_sol , obsurf_id
		From observation_surface os
		Join session on ses_id = id_session 
		Where ses_etat = '4' ) old_os
on surf_id = old_os.obs_id_surface;



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
		Join session on ses_id = id_session
		Join etat_surface es on es.code = code_etat_surface
		Join utilisation_sol us on us.code = code_utilisation_sol 
) os
on surf_id = os.obs_id_surface ;
--*************************************************************************
--Gestion utilisateur
--*************************************************************************
	--Création d'un utilisateur terrain
Create User Terrain;
	--Ajout d'un mot de passe à l'utilisateur
ALTER USER Terrain WITH PASSWORD 'terrain';
		
--Attribution du droit de visualisation de toutes les données
Grant Select On All Tables in Schema public to Terrain;
	-- Attribution de l'insertion et édition sur la table observation_surface
Grant UPDATE on public.observation_surface to Terrain;
Grant INSERT on public.observation_surface to Terrain;
Grant DELETE on public.observation_surface to Terrain;

Grant UPDATE on public.v_observation_surface to Terrain;
Grant INSERT on public.v_observation_surface to Terrain;
Grant DELETE on public.v_observation_surface to Terrain;
	-- Attribution de l'insertion et édition sur la table observation_bordure
Grant UPDATE on public.observation_bordure to Terrain;
Grant INSERT on public.observation_bordure to Terrain;
Grant DELETE on public.observation_bordure to Terrain;

Grant UPDATE on public.v_observation_bordure to Terrain;
Grant INSERT on public.v_observation_bordure to Terrain;
Grant DELETE on public.v_observation_bordure to Terrain;
	-- Attribution de l'insertion et édition sur la table session
Grant UPDATE on public.session to Terrain;
Grant INSERT on public.session to Terrain;
	--Attribution de l'utilisation des fonctions
GRANT EXECUTE on ALL functions in SCHEMA public to terrain;
	--Attribution de l'utilisation des séquences
GRANT USAGE on ALL sequences in schema public to terrain;






--delete from temp_bordure;
	--Réalisation de la fonction
select func_temp_bordure();

	--Activation de la fonction
Select public.func_create_bordure()

