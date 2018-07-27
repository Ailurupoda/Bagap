
# Bagap - Bordure/Parcelle

Détail de fonctionnement du projet, listing des actions réalisées sur la base de données et fonctionnement des interfaces créées.

## Introduction
Ce projet à pour but le suivi d'occupations et d'entretiens de parcelles et de bordures.

Une observation se fait sur une parcelle et une bordure à une date donnée décrite lors d'une session.

### I)	SQL
Les fichier *__update_keys.sql__*, *__view.sql__*, *__function.sql__* et *__trigger_maj_bordure.sql__* listent les modifications apportées à la base de données.

* **update_keys.sql** réorganise la base de données en ajoutant, modifiant et supprimant des colonnes et des contraintes sur les tables.
  * Ajout des champs de géométrie
  * Modification des clé primaires et étrangères
  * Mise à jour des données en fonction des nouvelles contraintes
  * Ajout de la table histo_fusion listant les entités à fusionner
  * Ajout d'un utilisateur "Terrain" pour une modification des observation seulement sur la session courante.


* **view.sql** créé les vues utilisées pour les interfaces.
  * *mv_zone*

  Cette vue créé et liste la géométrie des zones par l'union des parcelles de chacune des zones (connues par la première lettre de leur code).
  * *v_mod_session*

  Cette vue récupère simplement les informations relationnelles d'une session pour pouvoir afficher ces valeurs à la place des identifiant des clés étrangères.
  * *v_mod_bordure*

  Cette vue récupère simplement les informations relationnelles d'une bordure pour pouvoir afficher ces valeurs à la place des identifiant des clés étrangères.
  * *v_observation_bordure*

  Cette vue liste les observations réalisées sur la session courante avec la géométrie des bordures. Si aucune observation n'est encore signalée, une entité est tout de même créée avec des valeurs par défaut. C'est la vue qui va nous servir pour l'insertion des observation de bordure par des entités géographiques sur l'interface terrain de notre application.
  * *v_observation_bordure_tot*

  Cette vue liste toutes les observations réalisée couplée à la géométrie des bordures. Elle est utilisée pour afficher les observations des bordures sur l'interface bureau et simplifier l'interaction.
  * *v_observation_surface*

  Cette vue liste les observations réalisées sur la session courante avec la géométrie des parcelles. Si aucune observation n'est encore signalée, une entité est tout de même créée avec les valeurs des dernières observation effectuées sur la parcelle. C'est la vue qui va nous servir pour l'insertion des observation de parcelles par des entités géographiques sur l'interface terrain de notre application.
  * *v_observation_surface_tot*

  Cette vue liste toutes les observations réalisée couplée à la géométrie des parcelles. Elle est utilisée pour afficher les observations des parcelles sur l'interface bureau et simplifier l'interaction.  
  * *v_observation_fusion*

  Certaines parcelles peuvent évoluer dans le temps et fusionner, mais la fusion n'est visualisable que sur le terrain. Ainsi, une observation sur une parcelle fusionnée par l'union de trois autres se fait en réalité sur les trois parcelles. C'est avec cette vue que l'on récupère les informations des observations concernant les parcelles fusionnées. On créé ainsi des entités virtuelles fusionnées qui vont pouvoir avec un trigger réorienter les données dans les parcelles à l'origine de la fusion.
  * *mv_fusion_surface*

  Cette vue matérialiser liste les géométries des parcelles qui ont fusionnées.


* **function.sql** cré les fonctions de calcul et d'insertion.
  * *fun_create_bordure()*

 Cette fonction est utilisée une seule fois et permet la création de la géométrie des bordures. La géométrie d'une bordure correspond alors à un buffer de la lisière coupé par rapport à la parcelle correspondante à la bordure.
  * *fun_repare_bordure()*

  Cette fonction est utilisée une seule fois et réalise une correction de la géométrie des bordures pour éviter les superpositions. Elle va supprimer les parties superposées sur la bordure comprenant la surface la plus grande, dans le but de garder une zone cliquable suffisamment importante.
  * *fun_warning() -  <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction active automatiquement les warnings lorsqu'un commentaire est entrée dans une table.
  * *fun_edit_session() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction gère l'utilisation des session. Elle contraint la mise à jour étape par étape. La création d'une session n'est possible que la dernière session est validée. Il ne peut y avoir qu'une seule fois la même étape d'une session à l'exception de l'état "terminé".
  Il reste cependant possible de revenir à l'état "en cours", lorsque l'état courent est "à valider". Elle se lance lorsqu'une modification se fait sur la table session.
  * *fun_close_session() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction change automatiquement l'état de la session à "à validée" lorsque toutes les observation ont été réalisés. Elle est lancée pour chacune des nouvelles observation et calcul si c'est la dernière observation ou s'il en reste d'autre.
  * *fun_edit_terrain() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction restreint les modification de l'utilisateur terrain. Elle insère la donnée seulement si la session concernée est la courante, elle renvois une erreur dans le cas contraire.
  * *fun_edit_from_obs() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction met automatiquement à jour une session à l'état "en cours" lorsqu'une observation est ajoutée sur une session à l'état "créée".
  * *fun_obs_bord_maj() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction rend possible l'édition d'une vue. Elle détourne l'insertion de la vue "v_observation_bordure" vers la table "observation_bordure".
  * *fun_obs_surf_maj() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction rend possible l'édition d'une vue. Elle détourne l'insertion de la vue "v_observation_surface" vers la table "observation_surface".
  * *fun_tri_intersect_fusion() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction gère l'insertion des parcelles à fusionner. Elle met à jour les champs "hf_surf_id" et "hf_surf_ref" en fonction de l'intersection entre le point et les parcelles, ainsi que le numéro de l'union.
  La dernière étape est de recharger la vue matérialisée des fusions des parcelles.
  * *fun_tri_obs_fusion() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction rend possible l'édition d'une vue. Elle détourne l'insertion de la vue "v_observation_fusion" vers la table "observation_surface".

![Titre](bagap_MLD.png)
### II)	Interface terrain

Cette interface est vouées à être utilisée sur le terrain.

Les contraintes pour cet affichage sont :
* Ajouter des observations dans le cas où une session est présente
* Modifier seulement les observations de la session en cours
* Afficher les observations de la dernière session
* Suivre l'avancement du parcours sur le terrain

#### Contenu :
* Projet QGIS
Les couches contenus dans ce projet sont les suivantes :
  * lisiere
  * v_observation_bordure
  * v_observation_surface
  * utilisation_sol
  * etat_surface
  * session
  * v_mod_session
  * observateur
  * etat_session

		Nous utilisons ici des vues pour la modélisation des parcelles et des bordures.
Ces vues contiennent les informations des observations courrante ou celles de la session précédente si il n'en existe pas.
Ce sont ces vues qui seront éditées pour ajouter, modifier ou supprimer des observation sur l'interface Lizmap.

   Les autres couches sont présentes pour faire le lien entre les clés primaires et secondaires contenues dans la base de données et ainsi réaliser un affichage compréhensible.
Ainsi utilisation_sol, etat_surface et session apportent les informations textuelles pour les observations, et v_mod_session, observateur et etat_session, les informations textuelles pour les sessions.

   Nous utilisons une symbologie pour les couches v_observation_surface et v_observation_bordure renseignant sur l'avancée du travail sur la session courante. Une couleur est choisie pour les observations réalisée et une autre pour celles qui ne le sont pas.

* Paramètres Lizmap
   Pour cette interface, nous avons besoin d'afficher à la carte les lisières, bordures et surface, nous gardons ainsi dans la légende les couches lisiere, v_observation_surface et v_observation_bordure. Nous activons les popups pour les bordures et les surfaces dont nous voulons connaître les observations. Nous ajoutons la session en table attributaire.

   Pour finir, nous permettons l'édition et la suppression des couches v_observation_bordure, v_observation_surface et session.


Nous pouvons maintenant lancer l'interface sur le web, et visualiser nos couches, cliquer sur les entités et éditer des observations qui se mettrons à jour instantanément.
 en changeant de couleur.

 ### III)	Interface bureau
