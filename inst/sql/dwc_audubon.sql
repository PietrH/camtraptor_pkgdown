/*
Schema: https://rs.gbif.org/extension/ac/audubon_2020_10_06.xml
Camtrap DP terms and whether they are included in DwC (Y) or not (N):

media.mediaID                           Y: as link to observation
media.deploymentID                      N: included at observation level
media.sequenceID                        Y: as link to observation
media.captureMethod                     Y
media.timestamp                         Y
media.filePath                          Y
media.fileName                          Y: to sort data
media.fileMediatype                     Y
media.exifData                          N
media.favourite                         Y
media.comments                          Y
media._id                               Y
*/

-- Observations can be based on sequences (sequenceID) or individual files (mediaID)
-- Make two joins and union to capture both cases without overlap
WITH observations_media AS (
-- Sequence based observations
  SELECT obs.observationID, obs.timestamp AS observationTimestamp, med.*
  FROM observations AS obs
    LEFT JOIN media AS med ON obs.sequenceID = med.sequenceID
  WHERE obs.observationType = 'animal' AND obs.mediaID IS NULL
  UNION
-- File based observations
  SELECT obs.observationID, obs.timestamp AS observationTimestamp, med.*
  FROM observations AS obs
    LEFT JOIN media AS med ON obs.mediaID = med.mediaID
  WHERE obs.observationType = 'animal' AND obs.mediaID IS NOT NULL
)

SELECT
  obs_med.observationID                 AS occurrenceID,
-- provider: can be org managing the platform, but that info is not available
  {media_license}                       AS `dcterm:rights`,
  obs_med.mediaID                       AS identifier,
  CASE
    WHEN obs_med.fileMediatype LIKE '%video%' THEN 'MovingImage'
    ELSE 'StillImage'
  END                                   AS `dc:type`,
  obs_med._id                           AS providerManagedID,
  CASE
    WHEN obs_med.favourite AND obs_med.comments != '' THEN 'media marked as favourite | ' || obs_med.comments
    WHEN obs_med.favourite THEN 'media marked as favourite'
    ELSE obs_med.comments
  END                                   AS comments,
  dep.cameraModel                       AS captureDevice,
  obs_med.captureMethod                 AS resourceCreationTechnique,
  obs_med.filePath                      AS accessURI,
  obs_med.fileMediatype                 AS format,
  STRFTIME('%Y-%m-%dT%H:%M:%SZ', datetime(obs_med.timestamp, 'unixepoch')) AS CreateDate

FROM
  observations_media AS obs_med
  LEFT JOIN deployments AS dep
    ON obs_med.deploymentID = dep.deploymentID

ORDER BY
-- Order is not retained in observations_media, so important to sort
  obs_med.observationTimestamp,
  obs_med.timestamp,
  obs_med.fileName
