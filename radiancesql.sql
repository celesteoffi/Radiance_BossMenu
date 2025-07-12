/* ------------------------------------------------------------------
   1) Table ESX : job_grades
   ------------------------------------------------------------------
   • Sur la plupart des packs ESX, elle existe déjà.
   • On lui ajoute simplement la colonne JSON "permissions".
   • Si tu n’as pas la colonne salary, ajoute-la aussi.
------------------------------------------------------------------ */

ALTER TABLE job_grades
  ADD COLUMN IF NOT EXISTS salary       INT          NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS permissions  JSON         NOT NULL DEFAULT (JSON_OBJECT());


/* ------------------------------------------------------------------
   2) Table supplémentaire : bossmenu_defaults
   ------------------------------------------------------------------
   • Enregistre quel grade doit être attribué par défaut
     quand un joueur accepte /jobaccept.
------------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS bossmenu_defaults (
  job_name      VARCHAR(50)  NOT NULL,
  default_grade VARCHAR(10)  NOT NULL,
  PRIMARY KEY (job_name)
);
