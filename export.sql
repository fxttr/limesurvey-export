/*
  Author: Florian Marrero Liestmann
  Date: 15.09.2024
*/
/*
					Types "L", "!", "O", "D", "G", "N", "X", "Y", "5", "S", "T", "U"

					Description						Class Prefix		Legacy Character Code	Parent (if blank assume QuestionModule)
					5 point choice					FiveList			5	
					List (dropdown)					Select				!						List
					List (radio)					List				L	
					List with comment				CommentList			O						List
					Array							RadioArray			F						Array
					Array(10 point choice)			TenRadioArray		B						RadioArray
					Array (5 point choice)			FiveRadioArray		A						RadioArray
					Array (Increase/Same/Decrease)	IDRadioArray		E						RadioArray
					Array (Numbers)					NumberArray			:						Array
					Array (Texts)					TextArray			;						Array
					Array (Yes/No/Uncertain)		YNRadioArray		C						RadioArray
					Array by column					ColumnRadioArray	H						RadioArray
					Array dual scale				DualRadioArray		1						RadioArray
					Date/Time						Date				D	
					Equation						Equation			*	
					File upload						File				pipe character	
					Gender							Gender				G	
					Language switch					Language			I	
					Multiple numerical input		Multinumerical		K	
					Numerical input					Numerical			N	
					Ranking							Ranking				R	
					Text display					Display				X	
					Yes/No							YN					Y	
					Huge free text					HugeText			U						Text
					Long free text					LongText			T						Text
					Multiple short text				Multitext			Q	
					Short free text					ShortText			S						Text
					Multiple choice					Check				M	
					Multiple choice with comments	CommentCheck		P						Check
*/ 
DELIMITER $$

CREATE PROCEDURE p_CreateFieldMap(IN surveyid INT)
BEGIN
    DECLARE SurveyIDChar VARCHAR(100);
    DECLARE TableName VARCHAR(100);
    
    SET SurveyIDChar = CAST(surveyid AS CHAR);
    SET TableName = CONCAT('lime_survey_', SurveyIDChar);
    
    DROP TEMPORARY TABLE IF EXISTS TempLimeQuestionAnswers;

    CREATE TEMPORARY TABLE TempLimeQuestionAnswers (
        id INT NULL,
        qid INT NULL,
        Column_Name VARCHAR(255) NULL,
        parent_qid INT NULL,
        sid INT NULL,
        gid INT NULL,
        type VARCHAR(1) NULL,
        title VARCHAR(20) NULL,
        question TEXT NULL,
        subquestion TEXT NULL,
        Answer_Value TEXT NULL,
        preg TEXT NULL,
        help TEXT NULL,
        other VARCHAR(1) NULL,
        mandatory VARCHAR(1) NULL,
        question_order INT NULL,
        language VARCHAR(20) NULL,
        scale_id INT NULL,
        same_default INT NULL,
        relevance TEXT NULL,
        modulename VARCHAR(255) NULL
    );

    SET @SQL = CONCAT('
        INSERT INTO TempLimeQuestionAnswers (
            id, qid, Column_Name, parent_qid, sid, gid, type, title, question, subquestion, 
            Answer_Value, preg, help, other, mandatory, question_order, language, scale_id, 
            same_default, relevance, modulename
        )
        SELECT
            r.id,
            q.qid,
            CASE 
                WHEN q.other = ''Y'' THEN CONCAT(''', SurveyIDChar, 'X'', q.gid, ''X'', q.qid, ''other'')
                WHEN q.type = ''O'' THEN CONCAT(''', SurveyIDChar, 'X'', q.gid, ''X'', q.qid, ''comment'')
                ELSE CONCAT(''', SurveyIDChar, 'X'', q.gid, ''X'', q.qid)
            END AS Column_Name,
            q.parent_qid,
            q.sid,
            q.gid,
            q.type,
            q.title,
            q.question,
            sq.question AS subquestion,
            CASE 
                WHEN a.qid IS NOT NULL THEN a.answer
                ELSE r.Answer_Column
            END AS Answer_Value,
            q.preg,
            q.help,
            q.other,
            q.mandatory,
            q.question_order,
            q.language,
            q.scale_id,
            q.same_default,
            q.relevance,
            q.modulename
        FROM 
            lime_questions q
            JOIN lime_groups g ON q.gid = g.gid AND q.language = g.language
            LEFT JOIN lime_questions sq ON sq.parent_qid = q.qid
            LEFT JOIN lime_answers a ON a.qid = q.qid AND a.code = r.Answer_Column
            JOIN ', TableName, ' r ON r.sid = q.sid
        WHERE
            q.sid = ', surveyid, ' AND q.parent_qid = 0
        ORDER BY 
            g.group_order, q.question_order;
    ');

    PREPARE stmt FROM @SQL;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT * FROM TempLimeQuestionAnswers;

    DROP TEMPORARY TABLE IF EXISTS TempLimeQuestionAnswers;
END$$

DELIMITER ;