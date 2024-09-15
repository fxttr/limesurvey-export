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
ALTER PROCEDURE p_CreateFieldMap(@surveryid int)
AS
BEGIN
    /* Check if $sLanguage is a survey valid language (else $fieldmap is empty) */
    Declare @qid int, --Questiond ID
	        @sid int, -- Survey ID
			@sqid int, -- Subquestion ID
			@gid int,  -- Group ID
			@scale_id int, 
			@specialtype nvarchar(10), 
			@defaultvalue nvarchar(10),
	        @parent_qid int, -- Parent Question ID for SubQuestions
			@type varchar(1), -- Question Type
			@title nvarchar(max), -- Question Title
			@question nvarchar(max), -- Question Text
			@preg nvarchar(max) ,
	        @help nvarchar(max),  
			@other varchar(1), 
			@mandatory varchar(1),
			@question_order int,
			@language varchar(20),
	        @same_default int,
			@relevance varchar(max),
			@modulename nvarchar(255), 
			@SubQuestionsFound bit,
            @SQL nvarchar(max), -- for dynamic SQL
			@TableName nvarchar(100), -- Table name for survey responses
			@SurveyIDChar nvarchar(100), -- Convert Survey ID from int to varchar
	        @column_name nvarchar(100), -- From data dictionary
			@DerivedColumnName nvarchar(100), -- Derived from code
			@ParentQuestion nvarchar(max), -- Parent Question is the main question for the subquestion group
			@Answer_Value nvarchar(max), -- Answer value, not the code
			@Answer_ValueFromCode nvarchar(max), -- Answer value for code based answers
			@stitle nvarchar(max), -- Subquestion Title
			@squestion nvarchar(max), -- Subquestion Text
			@squestion_order int, -- Subquestion Order
			@SubQuestionPaddedNumber nvarchar(10), -- Zero Padded number
			@AnswerColumnName nvarchar(100), -- The response table column name
			@id int, -- reponse ID from the response table
			@ParmDefinition nvarchar(1000) -- Parameter list

	IF OBJECT_ID('tempdb..##TempLimeQuestionAnswers') IS NOT NULL
	   DROP Table ##TempLimeQuestionAnswers
	IF OBJECT_ID('tempdb..##TempLimeReponse') IS NOT NULL
	   DROP Table ##TempLimeReponse

	Set @DerivedColumnName = '';
	Set @SurveyIDChar = CAST(@surveryid as varchar(100));

	Set @TableName = 'lime_survey_' + @SurveyIDChar
	
	-- Prep Temp Answer Table
    Set @SQL='Select * into ##TempLimeReponse from '+ @TableName; 
    exec sp_executesql @SQL

	-- Answer Table Cursor
	declare curResponseTable cursor for 
	Select id from ##TempLimeReponse;

	-- Prep Temp Q&A Table 
	CREATE TABLE ##TempLimeQuestionAnswers(
        [id] int null,
        [qid] [int] NULL,
        [Column_Name] [nvarchar](max) NULL,
        [parent_qid] [int] NULL,
        [sid] [int] NULL,
        [gid] [int] NULL,
        [type] [varchar](1) NULL,
        [title] [nvarchar](20) NULL,
        [question] [nvarchar](max) NULL,
        [subquestion] [nvarchar](max) NULL,
        [Answer_Value] [nvarchar](max) NULL,
        [preg] [nvarchar](max) NULL,
        [help] [nvarchar](max) NULL,
        [other] [varchar](1) NULL,
        [mandatory] [varchar](1) NULL,
        [question_order] [int] NULL,
        [language] [varchar](20) NULL,
        [scale_id] [int] NULL,
        [same_default] [int] NULL,
        [relevance] [varchar](max) NULL,
        [modulename] [nvarchar](255) NULL	
	);

     OPEN curResponseTable
	 FETCH NEXT FROM curResponseTable INTO @id
	 WHILE @@FETCH_STATUS = 0  
	   BEGIN
			-- Main Query for Mapping
			declare curMainQuery cursor for
			SELECT [qid]
				  ,[parent_qid]
				  ,questions.[sid]
				  ,questions.[gid]
				  ,[type]
				  ,[title]
				  ,[question]
				  ,[preg]
				  ,[help]
				  ,[other]
				  ,[mandatory]
				  ,[question_order]
				  ,questions.[language]
				  ,[scale_id]
				  ,[same_default]
				  ,[relevance]
				  ,[modulename] 
			 FROM dbo.lime_questions as questions, dbo.lime_groups as groups
			 WHERE questions.gid=groups.gid AND 
				   questions.language=groups.language AND 
				   questions.parent_qid=0 AND
				   questions.sid = @surveryid
			 ORDER BY group_order, question_order;

			Open  curMainQuery
			Fetch Next from curMainQuery into @qid,@parent_qid,@sid,@gid,@type,@title,@question,@preg,@help,@other,@mandatory,@question_order,@language,@scale_id,@same_default,@relevance,@modulename 
			WHILE @@FETCH_STATUS = 0  
			BEGIN  
				Set @SubQuestionsFound = 0; -- init value
				-- Derive the column name
				Set @DerivedColumnName = @SurveyIDChar + 'X' + Cast(@gid as nvarchar(100))  + 'X' + Cast(@qid as nvarchar(100)) ; --"{$arow['sid']}X{$arow['gid']}X{$arow['qid']}

				IF @other = 'Y'
				   Set @DerivedColumnName = @DerivedColumnName + 'other'
					
				-- Is this a comment field?
				IF @type = 'O'  
					Set @DerivedColumnName = @DerivedColumnName + 'comment' 
        
				-- Multiple Comment
				 IF @type = 'P'  --$fieldname="{$arow['sid']}X{$arow['gid']}X{$arow['qid']}{$abrow['title']}comment"; 
					Set @DerivedColumnName = @DerivedColumnName + @title + 'comment' 

				-- is this a subquestion? 
				IF (select count(*) from dbo.lime_questions where parent_qid = @qid) > 0 -- We have subquestions. Use the count not the question type
				   Begin
						Set @DerivedColumnName = @DerivedColumnName + 'SQ';
						Set @SubQuestionsFound = 1;
						Set @ParentQuestion = @question; -- Since the cursor has parent_id=0 we know this is the parent question. 

						--Find all subquestions
						-- Cursor for parent_id 
						declare curSubQuestion cursor for
						select qid, title, question, question_order from dbo.lime_questions
						 where [sid] = @sid
						  and  gid = @gid
						  and  parent_qid = @qid
						order by question_order;

						Open curSubQuestion
						Fetch Next From curSubQuestion into @sqid, @stitle, @squestion, @squestion_order
						WHILE @@FETCH_STATUS = 0  
						BEGIN  
						-- Loop
							Set @SubQuestionPaddedNumber = Replace(STR(@squestion_order,3), ' ', '0'); -- padd with zeros
							Set @AnswerColumnName = @DerivedColumnName + @SubQuestionPaddedNumber;
							-- Get the answer
							SET @ParmDefinition = N'@Answer_Value nvarchar(100) output'
							Set @SQL = 'Select @Answer_Value= ['+ @AnswerColumnName +'] From ##TempLimeReponse where id =' + CAST(@id as nvarchar(100))
							exec sp_executesql @SQL, @ParmDefinition, @Answer_Value=@Answer_Value output

							Insert into ##TempLimeQuestionAnswers(
								   [id],[qid],[Column_Name],[parent_qid],[sid],[gid],[type],[title],[question],[SubQuestion],[Answer_Value],[preg],[help],[other],[mandatory],[question_order],[language],[scale_id],[same_default],[relevance],[modulename])
							Values(@id, @sqid,@AnswerColumnName, @parent_qid, @sid, @gid, @type, @stitle,@question, @squestion, @Answer_Value,@preg, @help, @other, @mandatory, @squestion_order, @language, @scale_id, @same_default, @relevance, @modulename );
							Fetch Next From curSubQuestion into @sqid, @stitle, @squestion, @squestion_order
					   END -- curSubQuestions
					   CLOSE curSubQuestion  
					   DEALLOCATE curSubQuestion 		 
				   End -- Array Questions
				IF @SubQuestionsFound = 0
				   Begin 					   
						-- Get the answer
						SET @ParmDefinition = N'@Answer_Value nvarchar(100) output'
						Set @SQL = 'Select @Answer_Value= ['+ @DerivedColumnName +'] From ##TempLimeReponse where id =' + CAST(@id as nvarchar(100))
						exec sp_executesql @SQL, @ParmDefinition, @Answer_Value=@Answer_Value output
						-- Check if this is a code
						IF (select count(*) from dbo.lime_answers where qid = @qid) > 0
						   BEGIN
								Select @Answer_ValueFromCode = [answer] From dbo.lime_answers where qid = @qid and code = @Answer_Value;
								Set @Answer_Value = @Answer_ValueFromCode;
						   END 
						Insert into ##TempLimeQuestionAnswers(
								[id],[qid],[Column_Name],[parent_qid],[sid],[gid],[type],[title],[question],[Answer_Value], [preg],[help],[other],[mandatory],[question_order],[language],[scale_id],[same_default],[relevance],[modulename])
						Values(@id,@qid,@DerivedColumnName, @parent_qid, @sid, @gid, @type, @title, @question, @Answer_Value, @preg, @help, @other, @mandatory, @question_order, @language, @scale_id, @same_default, @relevance, @modulename );
				   End      
				Fetch Next from curMainQuery into @qid,@parent_qid,@sid,@gid,@type,@title,@question,@preg,@help,@other,@mandatory,@question_order,@language,@scale_id,@same_default,@relevance,@modulename  	      
			END -- curMainQuery
			Close curMainQuery;
			Deallocate curMainQuery;		
			Fetch Next from curResponseTable into @id
    End --curResponseTable
	Close curResponseTable;		
	Deallocate curResponseTable;
        -- Replace the Select with an insert statement to place in a table. 
	Select * from ##TempLimeQuestionAnswers;
	-- Temp Table
	IF OBJECT_ID('tempdb..##TempLimeQuestionAnswers') IS NOT NULL
	   DROP Table ##TempLimeQuestionAnswers
	IF OBJECT_ID('tempdb..##TempLimeReponse') IS NOT NULL
	   DROP Table ##TempLimeReponse
END