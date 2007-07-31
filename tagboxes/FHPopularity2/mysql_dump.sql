# $Id: mysql_dump.sql,v 1.5 2007/07/31 23:20:36 jamiemccarthy Exp $
INSERT INTO tagboxes (tbid, name, affected_type, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'FHPopularity2', 'globj', 1, '2000-01-01 00:00:00', 0, 0, 0);
#INSERT INTO tagbox_userkeyregexes VALUES ('FHPopularity2', '^tag_clout$');

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity2_maxudcmult', '5', 'Maximum multiplier for an up/down tag based on the tags_udc table');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity2_udcbasis', '1000', 'Basis for tags_udc vote clout weighting');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity2_gracetime', '1200', 'Number of initial seconds of a firehose item life let it float higher in the hose');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity2_gracemult', '3', 'Multiplier factor for a firehose item during the grace period');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity2_gracevotes', '4', 'Max number of votes for which the grace period will apply');

