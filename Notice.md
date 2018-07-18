<style>
	.alna {
		text-indent:20px;
	}
</style>

# Bagap - Bordure/Parcelle

Détail de fonctionnement du projet, listing des actions réalisées sur la base de données et fonctionnement des interfaces créées.

## Introduction
Ce projet à pour but le suivi d'occupation et d'entretien de parcelle et de bordure.

Une observation se fait sur une parcelle et une bordure à une date donnée décrite lors d'une session.

### I)	SQL
Les fichier update_keys.sql et view.sql lisent les modifications apportées à la base de données.

Le premier ajoute, modifie et supprime des champs et clés primaires/étrangères, puis met à jour les données.

Le deuxième comporte la création des vues et des fonctions nécessaires au bon fonctionnement de la base de données et des interfaces liées.

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