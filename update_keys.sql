---------------------------------------------------------------
--Corentin FALCONE - 07/2018
--Fichier répertoriant les modifications des tables de la base
---------------------------------------------------------------


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

--********************************************
--Création des index
--********************************************

CREATE INDEX indx_bordure_fk
	ON public.bordure
	USING btree
	(bor_surf, bor_lisiere);
CREATE INDEX indx_bordure_code
	ON public.bordure
	USING btree
	(bor_code);

CREATE INDEX indx_surface_code
	ON public.surface
	USING btree
	(surf_code);

CREATE INDEX indx_lisiere_code
	ON public.lisiere
	USING btree
	(lis_code);


CREATE INDEX indx_observation_surface_fk
	ON public.observation_surface
	USING btree
	(obs_id_surface);
	

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

