test_that("AR(1) correlation matrix works", {
  corr_mat <- create_ar1_corr(3, 0.5)
  expect_equal(dim(corr_mat), c(3, 3))
  expect_equal(corr_mat[1,1], 1)
  expect_equal(corr_mat[1,2], 0.5)
})
