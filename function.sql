---------------------------------------------------------------
--Corentin FALCONE - 07/2018
--Fichier répertoriant les fonctions de la base de données
---------------------------------------------------------------


--/\**********************************************************/\
--************************************************************
--							FUNCTION
--************************************************************
--/\**********************************************************/\

--*********************************************************
--Fonction de création de géométrie bordure
--*********************************************************
CREATE OR REPLACE FUNCTION public.func_create_bordure()
	RETURNS integer AS
	--Fonction de création de la géométrie de bordures
	--Calcul de la palce disponible entre deux lisière pour créer la bordure
	--Réalisation d'un buffer en conséquence
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

		For b in  Select * From public.bordure LOOP	--Parcours des bordures
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
			nb = nb+1;

		END LOOP;
		
		RETURN nb;
	END;
$BODY$
	LANGUAGE 'plpgsql';





--*********************************************************
--Fonction de correction de la géométrie des bordures
--*********************************************************
-- DROP FUNCTION public.func_repare_bordure();
CREATE OR REPLACE FUNCTION public.func_repare_bordure()
	RETURNS integer AS
	--Fonction de découpage des bordures pour enlever la supperposition
	--Découpage de la plus petite bordure sur la plus grande
$BODY$
	DECLARE
		b public.bordure%rowtype;--Variable récupérant les données de la table bordure
		b2 public.bordure%rowtype; -- Variable récupérant les données de la table bordure à comparer 
		nb integer;--Variable comptant le nombre de mise à jour réalisées à retourner
	BEGIN
		nb = 0;--Initialisation à 0

			For b in Select * From public.bordure LOOP -- On parcours toutes les données de la table bordure
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
			END LOOP;

		RETURN nb;
	END;
$BODY$
	LANGUAGE plpgsql VOLATILE;



--*********************************************************************************
--Fonction de gestion des activation de warning quand un commentaire est entré
--*********************************************************************************
Create Or Replace function func_warning() 
	Returns trigger as
	--Fonction activant le warning lorsqu'un commentaire est entré 
$BODY$
	BEGIN
		IF NEW.commentaires is not null THEN -- Si il y a un commentaire
			NEW.warning = TRUE;--Activation du warning
		END IF;
		RETURN NEW;
	END;
$BODY$
LANGUAGE 'plpgsql';

--Attribution de la fonction trigger aux tables contenant des champs 'warning'
DROP TRIGGER if exists tri_check_warning on public.observation_surface;
DROP TRIGGER if exists tri_check_warning on public.observation_bordure;
DROP TRIGGER if exists tri_check_warning on public.session;
CREATE Trigger tri_check_warning
	BEFORE Insert or Update on public.observation_bordure
	FOR EACH ROW EXECUTE Procedure func_warning();
CREATE Trigger tri_check_warning
	BEFORE Insert or Update on public.observation_surface
	FOR EACH ROW EXECUTE Procedure func_warning();
CREATE Trigger tri_check_warning
	Before Insert or Update on public.session
	FOR EACH ROW EXECUTE Procedure func_warning();

--*********************************************************************************
--Function gestion des état session
--*********************************************************************************
Create Or Replace Function func_edit_session() 
	Returns Trigger as 
	--Fonction gérant la création de nouvelle sessions et la mise à jour des états
	--Sens de fonctionnement : créée --> en cours --> à valider --> validée --> terminée
	--											<-----
$BODY$
	DECLARE 
		nbValidee integer;--Compte le nombre de session 'validée'
		nbAv integer;--Compte le nombre de session 'à valider'
		nbEnCours integer;--Compte le nombre de session 'en cours', 'à valider', 'créée'
		etatEnCours public.session.ses_etat%TYPE;--ID de l'état 'en cours'
		etatAValider public.session.ses_etat%TYPE;--ID de l'état 'à valider'
		etatValidee public.session.ses_etat%TYPE;--ID de l'état 'validée'
		etatTermine public.session.ses_etat%TYPE;--ID de l'état 'terminée'
		etatCree public.session.ses_etat%TYPE;--ID de l'état 'créée'
	BEGIN
		-- Attribution des valeurs aux variables
		nbValidee = (Select count(*)
						From public.session
						Where ses_etat in (Select etses_id From public.etat_session Where etat = 'validée'));
		nbAV =(Select count(*)
						From public.session
						Where ses_etat in (Select etses_id From public.etat_session Where etat = 'à valider'));
		nbEnCours = (Select count(*)
						From public.session
						Where ses_etat in (Select etses_id From public.etat_session Where etat in ('en cours','créée','à valider')));
		etatEnCours = (Select etses_id From public.etat_session Where etat = 'en cours');

		etatAValider = (Select etses_id From public.etat_session Where etat = 'à valider');

		etatValidee = (Select etses_id From public.etat_session Where etat = 'validée');

		etatTermine = (Select etses_id From public.etat_session Where etat = 'terminée');

		etatCree = (Select etses_id From public.etat_session Where etat = 'créée');

		--Vérification de l'appel
		IF TG_OP = 'INSERT' THEN--Cas Insert
			--Vérification de l'état à modifier
			IF NEW.ses_etat = etatCree THEN--Cas 'créée'
				IF nbEnCours > 0 THEN--Si une session est déjà en cours : pas bon
					RAISE EXCEPTION 'Vous ne pouvez pas créer une nouvelle session sans valider les précédentes';
				ELSIF nbValidee != 1 THEN-- Si il n'y a pas de session validée : pas bon
					RAISE EXCEPTION 'Vous ne pouvez pas créer une nouvelle session sans valider les précédentes';
				END IF;--Cas contraire : OK
			ELSIF NEW.ses_etat is null THEN--Cas 'null'
				IF nbEnCours > 0 THEN--Si une session est déjà en cours : pas bon
					RAISE EXCEPTION 'Vous ne pouvez pas créer une nouvelle session sans valider les précédentes';
				ELSIF nbValidee != 1 THEN-- Si il n'y a pas de session validée : pas bon
					RAISE EXCEPTION 'Vous ne pouvez pas créer une nouvelle session sans valider les précédentes';
				ELSE--Cas contraire : on met l'état à 'créée'
					NEW.ses_etat = etatCree;
				END IF;	
			ELSE--Cas !null && !créée : pas bon
				RAISE EXCEPTION 'Vous ne pouvez pas créer de nouvelles session dans un état autre que : créée';
			END IF;

		ELSIF TG_OP = 'UPDATE' THEN--Cas Update
			IF nbValidee > 0 THEN-- Une session validée éxiste : On peut effectuer des modifications
				--Vérification de l'état à modifier
				IF NEW.ses_etat = etatCree THEN --Cas 'créée' : pas bon (seulement INSERT)
					RAISE EXCEPTION 'Etat inaccessible';	
				ELSIF NEW.ses_etat = etatEnCours AND OLD.ses_etat != etatCree THEN --Cas 'en cours' && old !'créée' : pas bon
					RAISE EXCEPTION 'Ne brulez pas les étapes';
				ELSIF NEW.ses_etat = etatAValider AND OLD.ses_etat != etatEnCours THEN --Cas 'à valider' && old !'en cours' : pas bon
					RAISE EXCEPTION 'Ne brulez pas les étapes';
				ELSIF NEW.ses_etat = etatValidee THEN-- Cas 'validée'
					IF OLD.ses_etat != etatAValider THEN--Si old !'à valider' : pas bon
						RAISE EXCEPTION 'Ne brulez pas les étapes';
					ELSE--Si old 'à valider'
						UPDATE public.session --Mise à jour du dernier validée en terminée
							SET ses_etat = etatTermine 
							Where ses_etat = etatValidee;
					END IF;
				ELSIF NEW.ses_etat = etatTermine AND (nbAV < 0 OR OLD.ses_etat != etatValidee) THEN --Cas 'terminée' && (0 à valider || old !validée) : pas bon
					RAISE EXCEPTION 'Impossible de terminée une session sans session validée';
				END IF;
			ELSE -- Pas de session 'validée' : pas bon
				RAISE EXCEPTION 'Action impossible';
			END IF;
		ELSIF TG_OP = 'DELETE' THEN-- Cas delete
			IF OLD.ses_etat in (Select etses_id From public.etat_session Where etat = 'validée') THEN
				--OLD : validée
				IF nbEnCours > 0 THEN--Si en cours : pas bon
					RAISE EXCEPTION 'Vous ne pouvez pas supprimer cette session';
				END IF;		
			END IF;
		END IF;
		RETURN NEW;
	END;
$BODY$
LANGUAGE 'plpgsql';
	--Attribution du trigger à la table session
DROP TRIGGER if exists tri_check_session on public.session;
CREATE Trigger tri_check_session
	BEFORE Insert or Update or Delete 
	ON public.session
	FOR EACH ROW 
	EXECUTE Procedure func_edit_session();


--*********************************************************************************
--Function cloture session
--*********************************************************************************
Create Or Replace Function func_close_session() 
	Returns Trigger as
	--Fonction finalisant la saisie sur le terrain en changeant l'état de la session automatiquement
	--Lorsque toutes les observations sont saisies, la session change d'état 
$BODY$
	DECLARE 
		nbSurf integer;--Nombre de surface total
		nbBord integer;--Nombre de bordure total
		surfOk boolean;--Check si le nombre de surface est égal au nombre d'observation en cours
		bordOk boolean;--Check si le nombre de bordure est égal au nombre d'observation en cours
		sesId integer;--Id de la session en cours
		etatS integer;--Id de l'état 'à valider'
	BEGIN
	--Attribution des valeurs aux variables
		Select ses_id 
			From public.session
			Where ses_etat in (Select etses_id
								From public.etat_session
								Where etat = 'créée' 
									Or etat = 'en cours')
		INTO sesId;
		Select etses_id 
			From public.etat_session
			Where etat = 'à valider'
		INTO etatS;

		Select count(*) 
			From public.observation_bordure 
			Where id_session = sesId
		INTO nbBord;

		Select count(*) 
			From public.observation_surface
			Where id_session = sesId
		INTO nbSurf;

		surfOk = (Select nbSurf = (Select count(*) From public.surface));
		bordOk = (Select nbBord = (Select count(*) From public.bordure));

		If surfOk and bordOk Then
			--Lorsque les observations sont toutes remplies on change l'état de la session en cours
			Update public.session 
				Set ses_etat = etatS
				Where ses_id = sesId;
		END IF;
		RETURN NEW;
	END;
$BODY$
LANGUAGE 'plpgsql';

	--Attribution de la fonction aux tables observation
DROP TRIGGER if exists tri_close_session on public.observation_surface;
DROP TRIGGER if exists tri_close_session on public.observation_bordure;
CREATE Trigger tri_close_session
	AFTER Insert 
	ON public.observation_surface
	FOR EACH ROW 
	EXECUTE Procedure func_close_session();
CREATE Trigger tri_close_session
	AFTER Insert
	ON public.observation_bordure
	FOR EACH ROW 
	EXECUTE Procedure func_close_session();


--*********************************************************************************
--Function gestion de l'édition pour l'utilisateur terrain
--*********************************************************************************
Create Or Replace Function func_edit_terrain() 
	Returns Trigger as
	--Fonction gérant l'entrée de nouvelles données pour l'utilisateur sur le terrain
	--L'utilisateur terrain en peu travailler que sur la session en cours
$BODY$
	DECLARE 
		user varchar;--Variable récupérant le nom de l'utilisateur
		session boolean;--Variable indiquant si la session est 'courante'
	BEGIN
		--Attribution des valeurs aux variables
		user = 
			(Select current_user);

		IF user = 'terrain' THEN --Test de l'utilisateur ayant déclenché le trigger
			IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN -- Si l'action est une insertion ou une édition
				session = 
					(Select ses_etat in (Select etses_id 
										From public.session 
										Join public.etat_session on ses_etat = etses_id 
										Where etat in ('en cours', 'créée'))
					From public.session
					Where ses_id = NEW.id_session);
					--On regarde si la session concernée est en cours
				IF not session THEN
				--L'utilisateur terrain ne peut éditer sur une session qui n'est pas en cours
					RAISE EXCEPTION 'Vous n avez pas les privilèges pour intervenir sur cette donnée';
				ELSE 
					RETURN NEW;
				END IF;
			ELSIF TG_OP = 'DELETE' THEN
				session = 
					(Select ses_etat in (Select etses_id 
										From public.session 
										Join public.etat_session on ses_etat = etses_id 
										Where etat in ('en cours', 'créée'))
					From public.session
					Where ses_id = OLD.id_session);
					--Lorsque l'on supprime une donnée on regarde l'ancien id et non le nouveau ('OLD')
				IF not session THEN
				--L'utilisateur terrain ne peut éditer sur une session qui n'est pas en cours
					RAISE EXCEPTION 'Vous n avez pas les privilèges pour supprimer la donnée, %', OLD.id_session;
				ELSE 
					RETURN OLD;
				END IF;
			END IF;
		ELSE
			--Cas des autres utilisateurs
			IF TG_OP = 'DELETE' THEN
				RETURN OLD;

			ELSIF TG_OP = 'UPDATE' or TG_OP = 'INSERT' THEN
				RETURN NEW;
			END IF;
			RETURN NEW;
		END IF;
	END;
$BODY$
LANGUAGE 'plpgsql';

	--Attribution de la fonction aux tables observation
DROP TRIGGER if exists tri_edit_terrain on public.observation_surface;
DROP TRIGGER if exists tri_edit_terrain on public.observation_bordure;
CREATE Trigger tri_edit_terrain
	BEFORE Insert or Update or Delete 
	ON public.observation_surface
	FOR EACH ROW 
	EXECUTE Procedure func_edit_terrain();
CREATE Trigger tri_edit_terrain
	BEFORE Insert or Update or Delete 
	ON public.observation_bordure
	FOR EACH ROW 
	EXECUTE Procedure func_edit_terrain();


--*********************************************************************************
--Function modification session créée --> en cours AUTO
--*********************************************************************************
CREATE OR REPLACE FUNCTION public.func_edit_from_obs()
	RETURNS trigger AS
	--Fonction modifiant l'état de la session créée lorsqu'une première observation est réalisée
$BODY$
	DECLARE 
		etatSess public.session.ses_etat%TYPE;--Etat de la session en cours
		etat_cree public.etat_session.etses_id%TYPE; --Id d'état 'créée'
		etat_ec public.etat_session.etses_id%TYPE;--Id d'état 'en cours'
	BEGIN
	--Attribution des valeurs aux variables	
		etatSess = (Select ses_etat 
					From public.session 
					Where id = NEW.id_session);
		etat_cree = (Select etses_id 
						From public.etat_session 
						Where etat = 'créée');
		etat_ec = (Select etses_id 
						From public.etat_session 
						Where etat = 'en cours');

		IF etatSess = etat_cree THEN
			--Lors d'un ajout d'observation, la session passe à 'en cours'
			Update public.session 
				Set ses_etat = etat_ec
				Where ses_id = NEW.id_session;
		END IF;
		RETURN NULL;
	END;
$BODY$
	LANGUAGE plpgsql VOLATILE;

--Attribution des fonctions aux tables observation
CREATE TRIGGER tri_edit_from_obs
	AFTER INSERT
	ON public.observation_bordure
	FOR EACH ROW
	EXECUTE PROCEDURE public.func_edit_from_obs();
CREATE TRIGGER tri_edit_from_obs
	AFTER INSERT
	ON public.observation_surface
	FOR EACH ROW
	EXECUTE PROCEDURE public.func_edit_from_obs();


-



--*********************************************************
--Update observation_bordure (Insert/Update/Delete)
--*********************************************************
CREATE OR REPLACE FUNCTION obs_bord_maj() 
	RETURNS TRIGGER AS 
	--Fonction d'insertion/édition/suppression des données par une vue
$$
	BEGIN
		IF (TG_OP = 'UPDATE') THEN
			--Cas d'édition
			IF NEW.vobs_id is null THEN
				--Cas de donnée non existante (INSERTION)
				INSERT INTO public.observation_bordure(warning, 
														commentaires, 
														abatt, 
														tet_emon, 
														cepee_cou,  
														rago_emon, 
														epara_bran, 
														epar_arbus, 
														elag_lamier, 
														emonde_hai, 
														coup_branc, 
														ent_coupel, 
														bali_cepee, 
														ha_aba_bal, 
														ha_abattue, 
														arbu_arrac, 
														arb_cou_cl, 
														plantation, 
														arbu_coupe, 
														paturage, 
														patu_piet, 
														fa_ss_arbu, 
														fauche, 
														broyage, 
														brulis, 
														debroussai, 
														labour, 
														talus_degr, 
														fa_ss_clot, 
														nb_arbu_coup, 
														talus_aras,
														obs_id_bordure,
														id_session)
				VALUES
					(NEW.warning, 
						NEW.commentaires, 
						NEW.abatt, 
						NEW.tet_emon, 
						NEW.cepee_cou,  
						NEW.rago_emon, 
						NEW.epara_bran, 
						NEW.epar_arbus, 
						NEW.elag_lamier, 
						NEW.emonde_hai, 
						NEW.coup_branc, 
						NEW.ent_coupel, 
						NEW.bali_cepee, 
						NEW.ha_aba_bal, 
						NEW.ha_abattue, 
						NEW.arbu_arrac, 
						NEW.arb_cou_cl, 
						NEW.plantation, 
						NEW.arbu_coupe, 
						NEW.paturage, 
						NEW.patu_piet, 
						NEW.fa_ss_arbu, 
						NEW.fauche, 
						NEW.broyage, 
						NEW.brulis, 
						NEW.debroussai, 
						NEW.labour, 
						NEW.talus_degr, 
						NEW.fa_ss_clot, 
						NEW.nb_arbu_coup, 
						NEW.talus_aras,
						NEW.bor_id,
						NEW.id_session);

				RETURN NEW;
			ELSE
				--Cas donnée existante (EDITION)
				UPDATE observation_bordure 
					SET warning = NEW.warning, 
						commentaires = NEW.commentaires, 
						abatt = NEW.abatt, 
						tet_emon = NEW.tet_emon, 
						cepee_cou = NEW.cepee_cou,  
						rago_emon = NEW.rago_emon, 
						epara_bran = NEW.epara_bran, 
						epar_arbus = NEW.epar_arbus, 
						elag_lamier = NEW.elag_lamier, 
						emonde_hai = NEW.emonde_hai, 
						coup_branc = NEW.coup_branc, 
						ent_coupel = NEW.ent_coupel, 
						bali_cepee = NEW.bali_cepee, 
						ha_aba_bal = NEW.ha_aba_bal, 
						ha_abattue = NEW.ha_abattue, 
						arbu_arrac = NEW.arbu_arrac, 
						arb_cou_cl = NEW.arb_cou_cl, 
						plantation = NEW.plantation, 
						arbu_coupe = NEW.arbu_coupe, 
						paturage = NEW.paturage, 
						patu_piet = NEW.patu_piet, 
						fa_ss_arbu = NEW.fa_ss_arbu, 
						fauche = NEW.fauche, 
						broyage = NEW.broyage, 
						brulis = NEW.brulis, 
						debroussai = NEW.debroussai, 
						labour = NEW.labour, 
						talus_degr = NEW.talus_degr, 
						fa_ss_clot = NEW.fa_ss_clot, 
						nb_arbu_coup = NEW.nb_arbu_coup, 
						talus_aras = NEW.talus_aras,
						obs_id_bordure = NEW.bor_id,
						id_session = NEW.id_session
				WHERE obsbrd_id = NEW.vobs_id;
				RETURN NEW;
			END IF;


	   	ELSIF (TG_OP = 'DELETE') THEN
	   		--Cas suppression
		   DELETE FROM observation_bordure where obsbrd_id = OLD.vobs_id;
		   RETURN OLD;
	   	END IF;
	   	RETURN NEW;
	END;
$$ LANGUAGE plpgsql;
	
	
	CREATE TRIGGER tri_maj_obs_bordure
INSTEAD OF INSERT OR UPDATE OR DELETE ON v_observation_bordure
FOR EACH ROW EXECUTE PROCEDURE obs_bord_maj();



--*********************************************************
--Update observation_surface (Insert/Update/Delete)
--*********************************************************

CREATE OR REPLACE FUNCTION obs_surf_maj() 
	RETURNS TRIGGER AS 
	--Fonction d'insertion/edition/suppression d'observation surface par une vue
$$
	BEGIN
		IF (TG_OP = 'UPDATE') THEN
			--Cas UDPATE
			RAISE NOTICE '%', NEW.vobs_id;
			IF NEW.vobs_id = 0 THEN
				--Cas inexistant (INSERT)
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
						NEW.surf_id,
						NEW.id_session);
				RAISE NOTICE 'Update 1';

				RETURN NEW;
			ELSE
				--Cas existant (UPDATE)
				UPDATE observation_surface
					SET warning = NEW.warning, 
						commentaires = NEW.commentaires, 
						hauteur = NEW.hauteur,
						code_etat_surface = NEW.code_etat_surface,
						code_utilisation_sol = NEW.code_utilisation_sol,
						obs_id_surface = NEW.surf_id,
						id_session = NEW.id_session
				WHERE obsurf_id = NEW.vobs_id;
				RAISE NOTICE 'Update 2';
				RETURN NEW;
			END IF;


	   	ELSIF (TG_OP = 'DELETE') THEN
	   		--Cas DELETE
			DELETE FROM observation_surface where obsurf_id = OLD.vobs_id;
			RETURN OLD;
	   	END IF;
	   	RETURN NEW;
	END;
$$ LANGUAGE plpgsql;
	
	
	CREATE TRIGGER tri_maj_obs_surface
INSTEAD OF INSERT OR UPDATE OR DELETE ON v_observation_surface
FOR EACH ROW EXECUTE PROCEDURE obs_surf_maj();



--Lancement de la création de bordure 
--delete from temp_bordure;
	--Réalisation de la fonction
select public.func_temp_bordure();

	--Activation de la fonction
Select public.func_create_bordure()
