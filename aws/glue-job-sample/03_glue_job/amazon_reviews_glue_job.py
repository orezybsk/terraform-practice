import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
## @type: DataSource
## @args: [database = "amazon-reviews", table_name = "amazon-reviews-input", transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
datasource0 = glueContext.create_dynamic_frame.from_catalog(database = "amazon-reviews", table_name = "amazon-reviews-input", transformation_ctx = "datasource0")
## @type: ApplyMapping
## @args: [mapping = [("marketplace", "string", "marketplace", "string"), ("customer_id", "long", "customer_id", "long"), ("review_id", "string", "review_id", "string"), ("product_id", "string", "product_id", "string"), ("product_parent", "long", "product_parent", "long"), ("product_title", "string", "product_title", "string"), ("product_category", "string", "product_category", "string"), ("star_rating", "string", "star_rating", "string"), ("helpful_votes", "long", "helpful_votes", "long"), ("total_votes", "long", "total_votes", "long"), ("vine", "string", "vine", "string"), ("verified_purchase", "string", "verified_purchase", "string"), ("review_headline", "string", "review_headline", "string"), ("review_body", "string", "review_body", "string"), ("review_date", "string", "review_date", "string"), ("col15", "string", "col15", "string"), ("col16", "string", "col16", "string"), ("col17", "long", "col17", "long"), ("col18", "string", "col18", "string"), ("col19", "string", "col19", "string"), ("col20", "string", "col20", "string"), ("col21", "string", "col21", "string"), ("col22", "string", "col22", "string"), ("col23", "string", "col23", "string"), ("col24", "long", "col24", "long"), ("col25", "long", "col25", "long"), ("col26", "string", "col26", "string"), ("col27", "string", "col27", "string"), ("col28", "string", "col28", "string"), ("col29", "string", "col29", "string"), ("col30", "string", "col30", "string")], transformation_ctx = "applymapping1"]
## @return: applymapping1
## @inputs: [frame = datasource0]
applymapping1 = ApplyMapping.apply(frame = datasource0, mappings = [("marketplace", "string", "marketplace", "string"), ("customer_id", "long", "customer_id", "long"), ("review_id", "string", "review_id", "string"), ("product_id", "string", "product_id", "string"), ("product_parent", "long", "product_parent", "long"), ("product_title", "string", "product_title", "string"), ("product_category", "string", "product_category", "string"), ("star_rating", "string", "star_rating", "string"), ("helpful_votes", "long", "helpful_votes", "long"), ("total_votes", "long", "total_votes", "long"), ("vine", "string", "vine", "string"), ("verified_purchase", "string", "verified_purchase", "string"), ("review_headline", "string", "review_headline", "string"), ("review_body", "string", "review_body", "string"), ("review_date", "string", "review_date", "string"), ("col15", "string", "col15", "string"), ("col16", "string", "col16", "string"), ("col17", "long", "col17", "long"), ("col18", "string", "col18", "string"), ("col19", "string", "col19", "string"), ("col20", "string", "col20", "string"), ("col21", "string", "col21", "string"), ("col22", "string", "col22", "string"), ("col23", "string", "col23", "string"), ("col24", "long", "col24", "long"), ("col25", "long", "col25", "long"), ("col26", "string", "col26", "string"), ("col27", "string", "col27", "string"), ("col28", "string", "col28", "string"), ("col29", "string", "col29", "string"), ("col30", "string", "col30", "string")], transformation_ctx = "applymapping1")
## @type: ResolveChoice
## @args: [choice = "make_struct", transformation_ctx = "resolvechoice2"]
## @return: resolvechoice2
## @inputs: [frame = applymapping1]
resolvechoice2 = ResolveChoice.apply(frame = applymapping1, choice = "make_struct", transformation_ctx = "resolvechoice2")
## @type: DropNullFields
## @args: [transformation_ctx = "dropnullfields3"]
## @return: dropnullfields3
## @inputs: [frame = resolvechoice2]
dropnullfields3 = DropNullFields.apply(frame = resolvechoice2, transformation_ctx = "dropnullfields3")
## @type: DataSink
## @args: [connection_type = "s3", connection_options = {"path": "s3://glue-job-sample-bucket/output"}, format = "parquet", transformation_ctx = "datasink4"]
## @return: datasink4
## @inputs: [frame = dropnullfields3]
datasink4 = glueContext.write_dynamic_frame.from_options(frame = dropnullfields3, connection_type = "s3", connection_options = {"path": "s3://glue-job-sample-bucket/output"}, format = "parquet", transformation_ctx = "datasink4")
job.commit()
